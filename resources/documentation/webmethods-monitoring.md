# webMethods Monitoring

## Overview

**WmMonitor** is the webMethods package responsible for tracking service and process executions and persisting that data to a database via a JDBC connection pool. This monitoring data can then be consulted and replayed from a dedicated monitoring UI.

WmMonitor is **not included in the official MSR base images** available from the webMethods container registry, and it cannot be installed via `wpm` — it is not published on [packages.webmethods.io](https://packages.webmethods.io). You need to build a container image using the **standard webMethods installer**.

An experimental alternative is to retrieve the `WmMonitor` directory from a manual installation, store it in a Git repository, and install it via `wpm` in the Dockerfile. This is not officially documented but appears to work correctly. It should not be implemented without Expert Labs guidance.

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

### Connecting the Microservice Runtime to the database

Once the database schema is in place, each MSR instance — integration microservices and the monitoring microservice alike — must be configured to use it. This is done by adding entries to the `application.properties` file.

**Declare a JDBC connection pool:**

```properties
jdbc.wmdb.dbURL=$env{POOL_JDBC_URL}
jdbc.wmdb.userid=$env{POOL_DB_USERNAME}
jdbc.wmdb.password=$env{POOL_DB_PASSWORD}
jdbc.wmdb.driverAlias=DataDirect Connect JDBC PostgreSQL Driver
```

The pool name (`wmdb` here) is arbitrary and can be anything meaningful. Sensitive values are injected via environment variables (like in the provided example) or via secrets.  
The `driverAlias` corresponds to the JDBC driver configured in the MSR.

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

