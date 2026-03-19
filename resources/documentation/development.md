# Development

##  Introduction

Developing cloud-native integrations with webMethods does not fundamentally differ from traditional Integration Server development. The same **Designer** IDE is used, and the full instruction set — flow services, document types, adapter services, JMS triggers, etc. — remains available.

That said, the cloud-native context introduces both constraints and opportunities, in particular:

**Constraints**
- **Stricter package dependency management** — since each MSR instance is isolated, inter-package dependencies must be explicit and carefully controlled.
- **Persistence discipline** — stateless container design means that any runtime state (files, in-memory data) that must survive a restart needs to be externalized (database, shared volume, messaging).

**Opportunities**
- **Full local development environment** — just like a Java developer running a Spring Boot app locally, a webMethods developer can spin up a complete integration stack on their workstation. No shared centralized dev server required.
- **True Git workflows** — In a traditional shared IS environment, the local Git repository lives on the central server, making it impossible for each developer to work on their own branch independently. With a local dev environment, each developer has their own local Git repository and can apply standard Git patterns: feature branches, pull requests, code reviews — exactly as in any modern software project.

## Development topologies

### Centralized (traditional)

The Designer runs locally on the developer's workstation and connects to remote, shared Integration Server instances (dev, test, etc.) hosted on central servers.

This is the traditional webMethods development model. It remains fully supported, but carries well-known limitations: developers share the same runtime, pessimistic locking is required to avoid conflicts, and Git workflows are constrained by the fact that the package directory — which is the Git working tree — lives on the shared server.

### Decentralized — local MSR

Each developer runs a local MSR instance on their workstation, with the Designer connected to it. The package directory is local, enabling a fully independent Git working tree per developer.

This unlocks standard branching workflows (feature branches, pull requests) but requires each developer to manually set up and maintain their local runtime dependencies.

### Decentralized — local Docker Compose stack

Each developer runs a complete integration stack locally using Docker Compose: MSR, message broker, database, and any other required infrastructure components. The Designer connects to the local MSR container.

This is the recommended approach. The entire environment is defined as code (`docker-compose.yml`), versioned alongside the package, and reproducible on any workstation. It mirrors production infrastructure closely, eliminates "works on my machine" issues, and fully unlocks Git-based collaboration workflows.

### Comparison

| | Centralized | Local MSR | Local Docker Compose |
|---|---|---|---|
| Developer isolation | None — shared runtime | Full | Full |
| Git workflows (feature branch, PR) | Limited | Yes | Yes |
| Environment reproducibility | Depends on shared server state | Manual setup | Defined as code |
| Proximity to production | Low | Medium | High |
| Onboarding effort | Low | Medium | Low (once compose file is ready) |

> The Docker Compose topology is the recommended approach for cloud-native webMethods development. The `resources/docker-compose-dev/` directory in this repository provides a ready-to-use stack for this project.

## Local Service Development (LSD)

The Designer includes a **Local Service Development** feature that further streamlines decentralized workflows. It embeds a Git client directly in the IDE and provides native integration with a locally running MSR deployed via Docker — making it possible to develop, version, and test integrations without leaving the Designer.

See the [official documentation](https://www.ibm.com/docs/en/webmethods-integration/wm-integration-server/11.1.0?topic=guide-using-local-service-development-feature) for setup and usage details.

> **Note:** The automatic integration between the Designer and a Docker-based MSR may not work in all environments — known cases include Docker running inside Windows WSL, or Podman as a container runtime. In such situations, integration packages hosted by the Docker container cannot be added to LSD. A simple workaround is to use symbolic links to point the MSR's packages directories to the local Git working tree, effectively achieving the same result without relying on LSD. In this case, the Git client embedded in the Designer will not be usable, but any other Git client will do the job.

## Additional tooling

**Text editor** — The Designer covers integration development, but a general-purpose text editor such as VS Code is highly recommended alongside it for editing Dockerfiles, YAML manifests, shell scripts, and configuration files. VS Code in particular offers rich support for Docker, Kubernetes, and YAML out of the box.

**wpm** — In addition to its role in image build (see [Image Build](image-build.md)), `wpm` can be used in a local dev environment to install adapter packages or utilities into the local MSR without having to rebuild the image.

**wMTestSuite** — The webMethods Test Suite remains the standard tool for implementing unit tests on flow services. It integrates with JUnit, making it straightforward to include integration tests in a CI/CD pipeline.
