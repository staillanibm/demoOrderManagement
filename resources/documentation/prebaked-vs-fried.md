# Pre-baked vs Fried

There are two broad approaches to packaging a webMethods integration microservice as a container image.

**Pre-baked** — the integration package and all its dependencies are installed into the image at build time. The resulting image is self-contained and immutable. This is the approach used in this repository and the cloud-native standard.

**Fried** — the base image is a generic, reusable MSR image with no business logic. Packages and dependencies are installed at container startup, typically via an init script or a custom entrypoint that pulls from a package registry (Git repository, artifact repository, etc.). There is no official tooling for this approach in self-hosted deployments — it must be implemented by the team.

## Comparison

| | Pre-baked | Fried |
|---|---|---|
| **Image reuse** | One image per microservice | Single generic base image shared across all microservices |
| **Image size** | Larger — each image embeds its packages | Smaller base image; packages fetched at runtime |
| **Build pipeline** | Standard — `docker build` produces the final artefact | Simpler build, but requires an init mechanism to be built and maintained |
| **Startup time** | Fast — everything is already in the image | Slower — packages must be downloaded and installed on every pod start |
| **Immutability** | Strong — the image is the artefact; what was tested is what runs | Weaker — runtime behaviour depends on the state of external registries at startup |
| **Reproducibility** | Guaranteed — the same image tag always produces the same runtime | Not guaranteed — a package update in the registry changes behaviour without a new image |
| **Rollback** | Trivial — redeploy a previous image tag | More complex — requires pinning exact package versions in the init script |
| **Secret handling** | Registry credentials (e.g. `WPM_TOKEN`) are only needed at build time and never reach the runtime | Registry credentials must be available at runtime inside every pod |
| **Security surface** | Smaller — no outbound registry calls at runtime, credentials not exposed to the container | Larger — runtime credentials, outbound network access, and init script logic all expand the attack surface |
| **Tooling** | Fully supported — standard Docker build, `wpm`, CI/CD pipelines | No official tooling for self-hosted deployments; must be implemented by the team |
| **Cloud-native alignment** | Strong — aligns with OCI image immutability principles | Weaker — diverges from the "build once, deploy anywhere" model |

## When fried makes sense

The main legitimate motivation for the fried approach is a **large number of microservices sharing a common base**. When dozens of pre-baked images must all be rebuilt, retested, and redeployed to apply a single MSR fix pack or OS patch, the operational overhead becomes significant. A single generic base image, patched once and shared across all microservices, can be easier to maintain at scale.

Outside of this scenario, pre-baked is the right default.

## A wider perspective: webMethods Integration SaaS Control Plane

The fried deployment model is one of the features offered by the **webMethods Integration SaaS Control Plane**. In that model, the control plane operates the runtime infrastructure, and deployments consist of pushing integration packages into managed runtimes — without ever building or owning a container image. This is conceptually similar to what other IBM products already do.

This represents a step away from strict cloud-native orthodoxy, but it can equally be read as a step towards a **serverless model**: the infrastructure is largely transparent, runtimes are provisioned and managed by the platform, and the team focuses exclusively on delivering integrations. The microservice packaging dimension — Dockerfiles, Kubernetes manifests, CI/CD pipelines — becomes less central, or disappears entirely.

This is a different operational model, with different trade-offs around control, portability, and vendor dependency. Both are valid. The self-hosted microservice approach described in this repository gives full control over the runtime and the deployment pipeline; the webMethods Integration control plane trades that control for operational simplicity.
