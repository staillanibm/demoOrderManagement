# Recommendations

## Don't use My webMethods Server and Mashzone with your integration microservices

Both **My webMethods Server (MWS)** and **Mashzone** are deprecated components that are not suited for cloud-native deployments.

**My webMethods Server** now serves only a handful of specific use cases. For integration monitoring, it is no longer needed — the dedicated MSR pattern described above covers that need without MWS. If an existing MWS deployment is in place for other specific purposes, it can be kept, but there is no reason to connect it to integration microservices.

**Mashzone** dashboards should be replaced by **Prometheus metrics** exposed by the MSR, visualized in a standard tool such as Grafana. This approach is lighter, more portable, integrates naturally with Kubernetes-native monitoring stacks, and does not introduce a dependency on a deprecated component. See [Observability](observability.md) for details.

## Make your integration microservices stateless

A stateless microservice does not retain any local state between requests or restarts. Any data that must outlive a single execution must be stored in an external system.

**What to avoid:**
- Writing to local files as a primary persistence mechanism.
- Relying on in-memory caches or session state that would be lost on container restart or scaling.

**What to do instead:**
- Persist data in external systems — databases (JDBC), messaging/event brokers, or object storage.
- If a file-based inbound channel is required, the polling directory must be backed by **network storage** (NFS, NAS, or a cloud-native equivalent) — not local pod storage. Files dropped by external producers must be visible to the MSR pod regardless of where it is scheduled, and must not be lost on restart.

A stateless design makes horizontal scaling straightforward, simplifies rolling updates, eliminates split-brain scenarios in multi-replica deployments, and greatly simplifies resilience and disaster recovery.

**Exception — Client-Side Queueing (CSQ):** When CSQ is enabled on a messaging broker connection, the MSR buffers outbound messages locally. This local buffer must survive pod crashes and restarts — which is fundamentally incompatible with a stateless deployment. Using CSQ therefore requires a **stateful deployment**: each pod needs its own persistent volume to store the buffer, and the deployment must ensure that a restarted pod reconnects to the same volume. This has significant implications on the Kubernetes deployment (StatefulSet instead of Deployment, per-pod PVCs). Be conscious of this trade-off before enabling CSQ.

## Make your integration microservices headless

A headless microservice exposes only the interfaces required for its integration function — API endpoints, queues, topics, or a file drop directory — and nothing else. It has no user-facing UI and its administration console is not exposed outside the cluster.

**What to avoid:**
- Exposing the MSR admin console (port `5555` web UI) through an ingress or load balancer in non-development environments. Note that this repository does exactly that — intentionally, for demonstration purposes.
- Connecting the Designer to production MSR instances.
- Relying on manual configuration through the admin console — all configuration must go through `application.properties` and the CI/CD pipeline.

**What to do instead:**
- Restrict access to the admin console to internal cluster traffic only (or disable it entirely in production).
- Treat the MSR as a black box in production: deploy it, monitor it via metrics and logs, and update it by building and deploying a new image.
- Use the admin console on development environments only, as a configuration helper (e.g. to generate the properties template).
- If a UI is needed for monitoring and replay, **dedicate a separate MSR deployment** to that purpose — this is the only instance that should expose a UI. It can be connected to an IdP or LDAP for authentication. See [webMethods Monitoring](webmethods-monitoring.md) for details on this pattern.

## Invest in automated testing

Accelerating delivery through CI/CD without a matching investment in automated testing is a risk multiplier. The faster you ship, the faster you can break production — unless tests act as a gate.

**What to use:**
- **curl** or **[Newman](https://github.com/postmanlabs/newman)** (the Postman CLI) cover most REST API testing needs and integrate naturally into a CI pipeline.
- **Shell scripts** are the pragmatic tool for file-based channel testing: generate a file, inject it, poll for the result.
- For more complex scenarios — multi-step flows, data validation, correlation across systems — standard tools quickly reach their limits. In those cases, invest in purpose-built test tooling. This is particularly true for **asynchronous flows**, where there is little off-the-shelf tooling that handles the polling, correlation, and timing concerns cleanly. The return on that investment is guaranteed.

**Where to put the tests:**
There is a genuine tension here. Keeping tests inside the microservice repository is the pragmatic choice — everything is in one place, tests travel with the code, and the CI pipeline has immediate access to them. Putting tests in a separate repository reduces the attack surface of the microservice image and enforces a cleaner separation between production code and test tooling. In practice, the right answer depends on the sensitivity of the target environment: for most integration microservices, co-locating tests with the code is the right default. For services handling regulated or sensitive data, the separation is worth the overhead.
