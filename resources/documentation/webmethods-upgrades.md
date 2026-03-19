# webMethods Upgrades

Adopting a microservice architecture for webMethods integrations has a somewhat underrated benefit: it fundamentally changes the nature of product upgrades.

## Why upgrades are easier

In a traditional monolithic IS deployment, upgrading the product version is a high-stakes operation. Every package hosted on the instance is affected, every team must validate, and getting a coordinated go-live across all stakeholders is often the main bottleneck. The blast radius of a failed upgrade is the entire integration platform.

With integration microservices, this changes on several fronts:

- **Rebuilding is fast.** Upgrading the webMethods runtime — whether it is a new product version or a fix pack — is a matter of updating the base image reference in the `Dockerfile` and triggering the CI/CD pipeline. The build, push, and deployment are fully automated.
- **Rollback is trivial.** If an issue is discovered after upgrading, rolling back means redeploying the previous image — a single command or a pipeline run. This is incomparably simpler than rolling back a fix pack on a virtualised IS instance.
- **The blast radius is contained.** Each microservice is upgraded independently. Only the teams responsible for that specific service need to be involved in the go-live decision. There is no need to align every integration team in the organisation to upgrade a shared platform.

## Continuous adoption

These properties create the conditions for a **continuous adoption** model: rather than treating webMethods version upgrades as infrequent, high-risk platform events, they can be handled as part of the normal application delivery cycle.

The practical implication is that keeping up with the latest fix packs — and the security patches they carry — becomes a routine operation rather than a project. The base image is updated, the pipeline runs, the tests validate, and the new version is in production. The same CI/CD pipeline that delivers application changes also delivers runtime updates.
