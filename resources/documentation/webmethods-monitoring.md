# webMethods Monitoring

## Overview

**WmMonitor** is the webMethods package responsible for tracking service and process executions and persisting that data to a database via a JDBC connection pool. This monitoring data can then be consulted and replayed from a dedicated monitoring UI.

## Installing WmMonitor

### Package installation

WmMonitor is **not included in the official MSR base images** available from the webMethods container registry.  
As of today it cannot be installed via `wpm` — it is not yet published on [packages.webmethods.io](https://packages.webmethods.io).  
The alternative is obtaining the package from a manual installation using the webMethods installer. This is not officially documented but appears to work correctly.  

**Example from the Dockerfile in this repository:**

```dockerfile
# The WmMonitor package
ADD --chown=1724:0 dependencies/packages/WmMonitor /opt/softwareag/IntegrationServer/packages/WmMonitor
```

This copies the WmMonitor package directory into the container image during the build process.

### ACL configuration

To activate the WmMonitor package, an **ACL (Access Control List) must be configured**. Currently, it is not possible to create ACLs via application properties, so the ACL configuration must be provided by mounting an `acls.cnf` file into the container.

The `acls.cnf` file must include a **MonitorUsers** ACL group that grants access to the appropriate user groups (for example Administrators).

**Example ACL configuration for WmMonitor:**

```xml
<record name="MonitorUsers" id="37" javaclass="com.wm.app.b2b.server.ACLGroup">
  <value name="name" id="38">MonitorUsers</value>
  <record name="allow" id="39" javaclass="com.wm.util.Values">
    <value name="local/Administrators" id="6">local/Administrators</value>
  </record>
  <record name="deny" id="40" javaclass="com.wm.util.Values">
  </record>
</record>
```

**Mounting the ACL file in the container:**

A complete example of the `acls.cnf` file is available in the `resources/docker-compose/` directory of this repository. The file must be mounted at `/opt/softwareag/IntegrationServer/config/acls.cnf` inside the container.

## Architecture

![Monitoring architecture](images/Monitoring.png)

Each integration microservice embeds WmMonitor alongside its business integration packages. A **dedicated monitoring microservice** — containing WmMonitor but no business packages — exposes the monitoring UI and is the single access point for operations teams.

> **The admin UI of integration microservices is off-limits**, except in exceptional circumstances. All flow consultation and replay is done exclusively through the monitoring microservice.

### Shared database: a pragmatic choice

All integration microservices and the monitoring microservice point their JDBC pool at the same **transversal webMethods database**. Every WmMonitor instance writes its execution data there, and the monitoring microservice reads across all of them from a single unified view.

Sharing a database between microservices is generally discouraged in a strict microservices architecture because it introduces data-level coupling. **This is a deliberate, pragmatic trade-off**: a shared database is the simplest way to centralise monitoring across a fleet of microservices. The alternatives — one monitoring UI per microservice, or an aggregation layer on top of separate databases — add operational or infrastructure complexity that is not justified here.

**This decision should be revisited if either of the following is observed:**
- **Performance bottleneck** — the shared database becomes a bottleneck under the combined write load of all microservices.
- **Coupling problems** — a schema migration or database outage affects all microservices simultaneously.

If that point is reached, the right move is to partition monitoring: each microservice (or logical group) gets its own monitoring database, and an aggregation layer is added if a unified view is still required.

## Database setup

### Creating the database components

The webMethods monitoring database is provisioned using the **Database Component Configurator** (DCC), part of the webMethods Installer. Full documentation is available at the [IBM documentation portal](https://www.ibm.com/docs/en/webmethods-integration/webmethods-installer/11.1.0?topic=ipcdccpdc-installing-products-using-webmethods-installer-creating-database-components-using-database-component-configurator).

Three components must be selected during the DCC configuration:

| Component | Purpose |
|---|---|
| **ISInternal** | Core Integration Server internal tables |
| **ISCoreAudit** | Service-level audit and execution tracking |
| **ProcessAudit** | Business process execution tracking |

#### JDBC URL formatting for PostgreSQL

The DCC requires a JDBC URL to connect to the target database. This same URL format will be reused when configuring the JDBC connection pool in the MSR `application.properties`.

**Basic DCC command example for PostgreSQL:**

```bash
./dbConfigurator.sh -a create -v latest \
  -u <db_username> \
  -p <db_password> \
  -d pgsql \
  -c ISInternal,ISCoreAudit,ProcessAudit \
  -l 'jdbc:wm:postgresql://<hostname>:<port>;DatabaseName=<database_name>'
```

**Placeholders:**
- `<db_username>` — Database user with sufficient privileges to create schemas and tables
- `<db_password>` — Database user password
- `<hostname>` — Database server hostname or IP address
- `<port>` — Database server port (default: `5432`)
- `<database_name>` — Target database name

#### Additional JDBC URL parameters

The JDBC URL supports additional parameters to control schema selection, TLS encryption, and certificate validation. These parameters are appended to the base URL using semicolons (`;`).

| Parameter | Purpose | Example Value |
|---|---|---|
| `initializationString` | Set the PostgreSQL search path to a specific schema (instead of `public`) | `SET search_path TO <schema>` |
| `EncryptionMethod` | Enable TLS encryption for the connection | `SSL` |
| `ValidateServerCertificate` | Verify the server's TLS certificate | `true` or `false` |
| `HostNameInCertificate` | Expected hostname in the server certificate | `<hostname>` |
| `TrustStore` | Path to the JKS file containing the trusted CA certificates | `<jks_location>` |
| `TrustStorePassword` | Password for the JKS truststore | `<password>` |


**Important notes:**
- When using `TrustStore`, the JKS file must be mounted inside the container at the specified location.
- Setting `ValidateServerCertificate=false` bypasses certificate validation — this should only be used in non-production environments.

### Connecting the Microservice Runtime to the database

Once the database schema is in place, each MSR instance — integration microservices and the monitoring microservice alike — must be configured to use it. This is done by adding entries to the `application.properties` file.

**Declare a JDBC connection pool:**

```properties
jdbc.wmdb.dbURL=$env{POOL_JDBC_URL}
jdbc.wmdb.userid=$env{POOL_DB_USERNAME}
jdbc.wmdb.password=$env{POOL_DB_PASSWORD}
jdbc.wmdb.driverAlias=DataDirect Connect JDBC PostgreSQL Driver
```

**Important notes:**
- The `dbURL` value should follow the same JDBC URL format described in the [JDBC URL formatting for PostgreSQL](#jdbc-url-formatting-for-postgresql) section above. The `$env{POOL_JDBC_URL}` environment variable must contain a properly formatted URL like `jdbc:wm:postgresql://<hostname>:<port>;DatabaseName=<database_name>` with any additional parameters as needed.
- The pool name (`wmdb` here) is arbitrary and can be anything meaningful. Sensitive values are injected via environment variables (like in the provided example) or via secrets.
- The `driverAlias` corresponds to the JDBC driver configured in the MSR.

**DataDirect Connect JDBC driver:**

The **DataDirect Connect JDBC driver** (`dd-cjdbc.jar`) should preferably be used to connect to the webMethods database. This is the recommended driver for JDBC connection pools used by WmMonitor and other webMethods components.

To make the driver available to the MSR:
1. Place the `dd-cjdbc.jar` file in the `common/lib/ext` directory
2. The MSR will automatically discover and load the driver on startup

**Example from the Dockerfile in this repository:**

```dockerfile
# Datadirect Connect JDBC driver, for use with JDBC pools (needed by the WmMonitor package)
ADD --chown=1724:0 dependencies/drivers/dd-cjdbc.jar /opt/softwareag/common/lib/ext/dd-cjdbc.jar
```

This ensures the driver is available for all JDBC connection pools that reference the `DataDirect Connect JDBC PostgreSQL Driver` alias.

**Bind the three components to the pool:**

```properties
jdbcfunc.ISCoreAudit.connPoolAlias=wmdb
jdbcfunc.ISInternal.connPoolAlias=wmdb
jdbcfunc.ProcessAudit.connPoolAlias=wmdb
```

On startup, the MSR will initialise each component against the shared database.

## Flow replay

When an operator decides to replay a flow from the monitoring UI, WmMonitor needs to know which Integration Server instance to target for the reinjection. This is configured via the `watt.net.localhost` extended setting, which each integration microservice sets to the name of its **Kubernetes / OCP service**.

When replaying a flow from the monitoring microservice, WmMonitor uses this tag to route the reinjection request to the correct Kubernetes service, which load-balances it across the healthy pods of that microservice.

