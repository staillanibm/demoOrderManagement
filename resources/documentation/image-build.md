# Image Build

Building a webMethods microservice image is straightforward: it uses a standard `Dockerfile` on top of an MSR base image pulled from the [webMethods container registry](https://containers.webmethods.io).

The approach followed here is **pre-baked**: a single image is built once and deployed as-is across all target environments (dev, staging, production). The image contains the runtime and the integration packages, but no environment-specific configuration — database connection strings, JMS aliases, credentials, etc. are all injected at deployment time via external configuration (see [External Configuration](external-configuration.md)). This ensures that the same artifact is promoted through the pipeline without being rebuilt per environment.

## Building the image

The image is built using the `docker-build` Makefile target:

```sh
make docker-build TAG=<image-tag>
```

This requires the `WPM_TOKEN` environment variable to be set — it is passed as a build argument to authenticate against the licensed webMethods package registry. The `TAG` variable controls the image tag; if omitted, it defaults to `latest`.

To push the built image to a registry, first authenticate, then push:

```sh
make docker-login-gh   # authenticate against GitHub Container Registry
make docker-push TAG=<image-tag>
```

> `docker-login-wm` is also available to authenticate against the webMethods container registry (used to pull the MSR base image).

## How the Dockerfile works

The [`Dockerfile`](../../Dockerfile) in this repository uses a **two-stage build**:

**Stage 1 — builder**
- Starts from the MSR base image.
- Uses `wpm` to install package dependencies from the [official registry](https://packages.webmethods.io) — in this case the `WmJDBCAdapter` package. This stage requires a `WPM_TOKEN` build argument to authenticate against the licensed registry.
- Downloads the PostgreSQL JDBC driver JAR directly.
- Copies the content of this repository into the `packages/` directory of the MSR.
- Grants group ownership and write permissions on the entire `softwareag` directory to group `0` (root group). The official MSR base image is already OpenShift-compatible, but anything added on top of it — installed packages, copied files — must follow the same rules. OCP runs containers with an arbitrary user ID but always with group `0`, so this step ensures that everything added during the build remains accessible at runtime.

**Stage 2 — final image**
- Starts from a fresh MSR base image.
- Copies only the `IntegrationServer/` directory from the builder stage.

The two-stage approach ensures that build-time secrets (the `WPM_TOKEN`) are not embedded in the final image — they are only present in the intermediate builder layer, which is discarded.

> This is one way to handle build-time secrets. Other approaches exist, such as using Docker BuildKit secret mounts (`--secret`).

## Package installation strategies

In this example, the custom package (`demoOrderManagement`) is added to the image by copying the repository content directly into `packages/`. Alternatively, `wpm` could be used to install the package from a Git repository, which may be preferable in a fully automated pipeline.

An image can include any number of custom packages — simply copy or install them into the `packages/` directory. That said, best practices apply: keep each microservice focused on a well-defined functional scope, and avoid bundling unrelated packages in the same image.

## Corporate base image

For real-world enterprise deployments, building each microservice image directly on top of the official MSR image quickly becomes repetitive and hard to maintain: every team ends up re-installing the same adapters, drivers, and framework packages, and enforcing the same internal standards.

The recommended approach is to introduce a **corporate base image**, built and maintained by a central platform team. This image sits between the official MSR image and the individual microservice images, and consolidates everything that is shared across the organization:

| Layer | Content |
|---|---|
| **MSR base image** | Bare MSR runtime from the webMethods registry |
| **Corporate base image** | webMethods packages (adapters, connectors), drivers, corporate integration framework packages |
| **Microservice image** | Microservice-specific packages only |

This three-tier model has several benefits:
- **Complexity is factored out** — the corporate base image absorbs the hard parts (wpm authentication, driver installation, OCP permissions). Microservice Dockerfiles become trivial.
- **Standards are enforced centrally** — adapter versions, security patches, and corporate framework updates are applied in one place and inherited by all microservice images automatically on the next rebuild.
- **Developer environments are consistent** — developers use the corporate base image locally, ensuring that what runs on their workstation matches what is deployed in production.

> The `Dockerfile` in this repository builds directly on the official MSR image for simplicity. In an enterprise context, the `FROM` instruction should reference the corporate base image instead.
