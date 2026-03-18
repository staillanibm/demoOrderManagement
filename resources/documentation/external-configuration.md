# External Configuration

The MSR follows a **configuration as code** approach: all environment-specific settings are provided at startup via one or more `application.properties` files, without any modification to the image itself. This is what makes the pre-baked image model work — the same image is deployed in every environment, and the configuration varies.

The full list of supported configuration variables is documented in the [official reference](https://www.ibm.com/docs/en/webmethods-integration/wm-microservices-runtime/11.1.0?topic=guide-configuration-variables-template-assets). Note that this reference does not cover the additional properties exposed by adapters and connectors (JDBC, JMS, CloudStreams, etc.), which follow their own naming conventions.

For a general introduction to the mechanism, see [Using Configuration Variables Templates](https://www.ibm.com/docs/en/webmethods-integration/wm-microservices-runtime/11.1.0?topic=guide-using-configuration-variables-templates-microservices-runtime).

## What can be configured

The properties file covers a broad range of settings, including:

| Category | Examples |
|---|---|
| **Server settings** | Extended settings (`watt.*`), default content type, locking mode, etc. |
| **Security** | Administrator password, additional users and group memberships, etc. |
| **Adapter and CloudStreams connector connections** | connection parameters (host, port, database, credentials) |
| **JMS** | JNDI provider URL, connection alias settings, retry parameters |
| **Keystores / Truststores** | TLS certificate configuration |

## Example

The Kubernetes ConfigMap at [`resources/kubernetes/config-map.yaml`](../../resources/kubernetes/config-map.yaml) embeds an `application.properties` that illustrates several categories of configuration:

```properties
# JDBC connection alias — values injected from Kubernetes secrets
artConnection.demoOrderManagement.demoOrderManagement.jdbc.orders_postgres.connectionEnabled=true
artConnection.demoOrderManagement.demoOrderManagement.jdbc.orders_postgres.connectionSettings.serverName=$secret{DB_SERVER_NAME}
artConnection.demoOrderManagement.demoOrderManagement.jdbc.orders_postgres.connectionSettings.portNumber=$secret{DB_PORT}
artConnection.demoOrderManagement.demoOrderManagement.jdbc.orders_postgres.connectionSettings.databaseName=$secret{DB_DATABASE_NAME}
artConnection.demoOrderManagement.demoOrderManagement.jdbc.orders_postgres.connectionSettings.user=$secret{DB_USERNAME}
artConnection.demoOrderManagement.demoOrderManagement.jdbc.orders_postgres.connectionSettings.password=$secret{DB_PASSWORD}

# JMS / JNDI — with TLS truststore configuration
jndi.DEFAULT_IS_JNDI_PROVIDER.providerURL=$secret{JNDI_URL}
jndi.DEFAULT_IS_JNDI_PROVIDER.trustStoreAlias=UM_TRUSTSTORE
jms.DEFAULT_IS_JMS_CONNECTION.enabled=true
jms.DEFAULT_IS_JMS_CONNECTION.jndi_jndiAliasName=DEFAULT_IS_JNDI_PROVIDER
jms.DEFAULT_IS_JMS_CONNECTION.producerMaxRetryAttempts=30
jms.DEFAULT_IS_JMS_CONNECTION.producerRetryInterval=1000

# Extended settings
settings.watt.net.default.accept=application/json
settings.watt.server.ns.lockingMode=none

# Users
user.Administrator.password=$secret{ADMIN_PASSWORD}
user.tester.password=$secret{TESTER_PASSWORD}
group.Everybody.users=tester

# Global variable populated from a pod environment variable
globalvariable.SERVER.value=$env{HOSTNAME}

# Truststore
truststore.UM_TRUSTSTORE.ksLocation=/certs/um/um-truststore.jks
truststore.UM_TRUSTSTORE.ksPassword=$secret{UM_TRUSTSTORE_PASSWORD}
```

In a Kubernetes deployment, the ConfigMap is mounted as a volume and the MSR reads the properties file at startup. Secrets are referenced inline via `$secret{}` and resolved by the MSR from the mounted Kubernetes Secrets.

## Generating the properties file

The MSR admin console includes a built-in helper to bootstrap the properties file. Under **Microservices → Configuration Variables → Generate Configuration Variables Template**, the console generates an `application.properties` file reflecting the current server configuration — all resources configured on the dev server (JDBC connections, JMS aliases, etc.) are exported with their properties.

The generated file is typically large, as it includes every configurable property for every resource. **It should not be used as-is.** The recommended approach is to trim it down significantly: remove everything that is either static (will never change across environments) or irrelevant to the deployment target. In practice, for each resource, only a handful of properties need to be kept — typically server name, port, database name, and credentials — which amounts to around ten properties per resource at most.

## Properties delivery strategies

There are two common approaches for delivering the properties file to the MSR, and both are valid:

- **Baked into the image** — the `application.properties` file is copied into the image at build time. The image is then self-contained and ready to run. This works well when the set of properties is stable and does not vary significantly across environments.
- **Mounted at runtime** — the properties file is stored in a ConfigMap (or equivalent) and mounted into the container at startup. This keeps the image fully generic and delegates all configuration to the deployment layer.

The key constraint is the same in both cases: **no sensitive value should ever be hardcoded** in the properties file. Credentials, tokens, and passwords must always be injected at runtime using one of the strategies described below.

## Secret injection strategies

The MSR supports several mechanisms for injecting sensitive values into properties at startup:

| Strategy | Syntax | Typical use case |
|---|---|---|
| **Environment variable** | `$env{VAR_NAME}` | Docker Compose, CI/CD pipelines, any environment where env vars are easily set |
| **Secret file** | `$secret{SECRET_KEY}` | The MSR looks for a file named `SECRET_KEY` in `/etc/secrets` (configurable) and reads its content as the value |
| **HashiCorp Vault** | Native integration | Environments where secrets are centrally managed in a Vault — the MSR fetches values directly at startup without any intermediate file |

For HashiCorp Vault integration, see the [official documentation](https://www.ibm.com/docs/en/webmethods-integration/wm-integration-server/11.1.0?topic=guide-integrating-hashicorp-vault).

These strategies can be combined within the same properties file: non-sensitive values can be hardcoded, environment-specific endpoints injected via `$env{}`, and credentials via `$secret{}` or Vault.

### How `$secret{}` works

When the MSR encounters `$secret{FOO}`, it looks for a file named `FOO` in `/etc/secrets` and uses its content as the value. The directory can be changed via configuration. The mechanism is intentionally simple: **any tool that can place a correctly named file with the right content in that directory will work**, regardless of the underlying secret management solution. For example:

- **Kubernetes Secrets** mounted as a volume into `/etc/secrets` — the standard approach, where each key in the Secret becomes a file.
- **External Secrets Operator** — synchronizes secrets from an external store (AWS Secrets Manager, Azure Key Vault, etc.) and creates Kubernetes Secrets that are then mounted normally.
- **HashiCorp Vault agent as a sidecar** — the Vault agent injects secret files directly into the container filesystem at the expected path and with the expected naming convention, without requiring any Kubernetes Secret in between.

## Keystores and truststores

TLS keystores and truststores (`.jks` files) are binary artifacts that cannot be embedded in a properties file. They must be made available to the MSR as files at a known path inside the container, then referenced in the properties file.

**Step 1 — mount the file into the container**

In Kubernetes, the JKS file is stored in a Secret (as a base64-encoded value) and mounted at a specific path via a volume mount. In this repository, the UM truststore is mounted at `/certs/um/um-truststore.jks`:

```yaml
# In deployment.yaml
volumeMounts:
  - name: um-truststore
    mountPath: /certs/um/um-truststore.jks
    subPath: um-truststore.jks
    readOnly: true

volumes:
  - name: um-truststore
    secret:
      secretName: um-truststore
      items:
        - key: um-truststore.jks
          path: um-truststore.jks
```

**Step 2 — declare the truststore in application.properties**

The MSR is then told where to find the file and how to open it:

```properties
truststore.UM_TRUSTSTORE.ksLocation=/certs/um/um-truststore.jks
truststore.UM_TRUSTSTORE.ksPassword=$secret{UM_TRUSTSTORE_PASSWORD}
```

The alias (`UM_TRUSTSTORE`) can then be referenced by other properties — for example, the JNDI provider TLS configuration:

```properties
jndi.DEFAULT_IS_JNDI_PROVIDER.trustStoreAlias=UM_TRUSTSTORE
```

The same pattern applies to keystores for mutual TLS (mTLS) scenarios.
