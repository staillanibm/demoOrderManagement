# Cloud-native webMethods Platform

## Microservices Runtime

The **Microservices Runtime (MSR)** is the modern, cloud-native version of the Integration Server. It is designed to run integration packages as lightweight, containerized microservices. It is webMethods' equivalent to **WebSphere Liberty**, IBM's cloud-native runtime for WebSphere applications.

| | |
|---|---|
| **Lightweight** | Only embeds the core webMethods Integration packages. Can easily be extended using the webMethods package manager (`wpm`). |
| **Configurable** | Implements a *configuration as code* approach, with bindings to config maps, secrets and vaults. |
| **Observable** | Continuous publishing of metrics and OpenTelemetry traces. |

The MSR also introduces several structural simplifications compared to the traditional Integration Server:

- **No Tanuki wrapper** — the MSR runs as a standard JVM process, without the Service Wrapper daemon used to manage the IS as a system service.
- **Simplified directory layout** — the MSR is single-instance by design, so packages, logs, and configuration are stored directly under the `IntegrationServer/` directory, without the multi-instance indirection layer of a classic IS installation.
- **Simplified package installation** — deploying a package is as simple as copying it into the `IntegrationServer/packages/` directory; no installer or admin console required.

Despite its smaller form factor, the MSR is a superset of the Integration Server. Integrations implemented with the Integration Server can therefore be ported to the Microservices Runtime with low refactoring effort.
See the [official MSR vs Integration Server comparison](https://www.ibm.com/docs/en/webmethods-integration/wm-microservices-runtime/11.1.0?topic=guide-microservices-runtime-vs-integration-server) for details.

MSR base images are available from the [webMethods container registry](https://containers.webmethods.io). Alternatively, an MSR image can be built using the standard webMethods installer.

## webMethods Package Manager (wpm)

Because the MSR only embeds a minimal set of core packages, additional capabilities — adapters, connectors, utilities — must be installed on top of it. This is the role of `wpm`, webMethods' package manager, conceptually similar to `npm` (Node.js), `pip` (Python), or Maven (Java). It handles the installation and dependency management of Integration Server / MSR packages.

Since webMethods Integration v11, `wpm` is bundled in all base images available from the [webMethods container registry](https://containers.webmethods.io), making it available out of the box in any containerized setup.

The official package registry is [packages.webmethods.io](https://packages.webmethods.io), which hosts:

- **Adapters** — JDBC, SAP, and other technology adapters
- **CloudStreams connectors** — pre-built connectors to SaaS and cloud platforms
- **Utilities** — e.g. end-to-end monitoring agents

In addition to the official registry, `wpm` can install packages directly from remote Git repositories, making it straightforward to manage custom or private packages alongside official ones.
