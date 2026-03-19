# CI/CD

There is no single correct CI/CD pipeline design — multiple valid approaches exist, and the best one is usually the one that aligns with the DevOps practices already in place in the organisation. A webMethods integration microservice pipeline should not look fundamentally different from a Spring Boot or Node.js pipeline. The tooling, the stages, and the conventions can be identical.

The only webMethods-specific step is the image build, which installs packages via `wpm` and copies the integration package into the MSR base image (see [Image Build](image-build.md)). Once the container image is built and pushed to a registry, everything that follows is standard: the deployment target is a container platform, the artefact is an OCI image, and any mainstream CI/CD tool can take it from there.

**CI/CD platforms** — all of the following integrate naturally with a containerised deployment workflow:
- GitHub Actions
- GitLab CI
- Azure Pipelines
- Jenkins
- Tekton

**GitOps** — for teams that manage deployment state declaratively, tools such as **ArgoCD** or **Flux** work without modification: they watch a Git repository for changes to Kubernetes manifests and reconcile the cluster state accordingly. The Kustomize manifests in this repository are directly compatible with this approach.

---

## This repository's example

The workflow at `.github/workflows/cicd.yaml` is intentionally kept simple: for didactic purposes, everything is in a single file with three sequential jobs — build, deploy, test. It uses GitHub Actions, but the same logic applies to any other CI/CD platform.

The workflow is triggered manually (`workflow_dispatch`). The push trigger is commented out — uncomment it to enable automatic builds on every push to `main`.

### Job: `build-and-push`

Builds the microservice image and pushes it to the target container registry.

| Step | Description |
|---|---|
| Checkout Code | Checks out the repository |
| Log in to target Container Registry | Authenticates to the registry where the microservice image will be pushed |
| Log in to base Container Registry | Authenticates to `containers.webmethods.io` to pull the MSR base image during the build |
| Build microservice Image | Runs `docker build`, passing `WPM_TOKEN` as a build argument for `wpm` to install dependencies |
| Push microservice Image | Pushes the built image to the target registry |
| Save Tag for Later | Writes the image tag to `$GITHUB_OUTPUT` so the `deploy` job can reference it |
| Tag repository | Creates a Git tag matching the image tag and pushes it to the repository |

The image tag is constructed as `MAJOR_VERSION.MINOR_VERSION.<run_number>` — the run number acts as the patch version and increments automatically with each pipeline execution.

### Job: `deploy`

Deploys the newly built image to the Kubernetes / OpenShift cluster.

| Step | Description |
|---|---|
| Checkout Code | Checks out the repository (needed for the Kustomize manifests) |
| Set up kubeconfig | Writes the kubeconfig from a GitHub secret to `~/.kube/config` |
| Test cluster connectivity | Runs `kubectl get nodes` to verify the connection before proceeding |
| Deploy | Uses `kustomize edit set image` to update the image tag in `kustomization.yaml`, then applies all manifests with `kubectl apply -k` and waits for the rollout to complete (5-minute timeout) |
| Sanity check | Queries all running, ready pods and calls `GET /health` on each via `kubectl exec`. Fails the pipeline if any pod returns a non-200 response. Terminating pods (from the previous deployment) are explicitly excluded using `jq` to filter on `deletionTimestamp == null`. |

### Job: `test`

Runs functional tests against the deployed microservice.

| Step | Description |
|---|---|
| Checkout Code | Checks out the repository (needed for the test scripts in `resources/tests/`) |
| Set up kubeconfig | Same as in the `deploy` job |
| Retrieve test credentials | Resolves the service URL from the OCP Route or Kubernetes Ingress (tries Route first, falls back to Ingress). Reads the `TESTER_PASSWORD` from the Kubernetes Secret and masks it in the logs. |
| Test - File inbound channel | Calls `injectFile.sh` to drop a CSV file into the PVC via the `busybox-pvc-browser` helper pod. Captures the two generated order IDs for later verification. |
| Test - REST API inbound channel | Calls `postOrder.sh` to submit an order via the REST API. Fails immediately if the response is not HTTP 202. |
| Verify - orders persisted | Polls `GET /OrdersAPI/orders/{id}` for each of the three orders (2 from file, 1 from API) until HTTP 200 is received or a 90-second timeout is reached. The longer timeout accounts for the file polling interval (60 seconds by default). |

### Cluster authentication

Storing the kubeconfig in a GitHub secret and writing it to `~/.kube/config` at runtime is a deliberately simple approach. It is fully portable — it works identically for Kubernetes and OpenShift — and requires no cluster-side configuration. In practice, enterprise environments will typically use more secure mechanisms: OIDC federation between the CI/CD platform and the cluster, short-lived tokens, or dedicated service accounts with scoped permissions. Cluster authentication is out of scope for this repository — the goal here is to demonstrate CI/CD automation for a webMethods integration microservice, not to prescribe how to connect a pipeline to a cluster.

### Rollbacks

The pre-baked image approach makes rollbacks straightforward. Every build produces a versioned, immutable image tagged and pushed to the registry — rolling back is simply a matter of deploying a previous image.

**Option 1 — `kubectl rollout undo`:** Kubernetes keeps a history of previous ReplicaSets. A rollback to the immediately preceding revision can be triggered with:

```sh
kubectl rollout undo deployment/<deployment-name> -n <namespace>
```

To roll back to a specific revision:

```sh
kubectl rollout history deployment/<deployment-name> -n <namespace>   # list revisions
kubectl rollout undo deployment/<deployment-name> -n <namespace> --to-revision=<n>
```

This is the fastest path — no registry interaction, no pipeline required.

**Option 2 — redeploy via CI/CD:** Trigger the pipeline with the tag of a previous image. This is the preferred approach when the rollback needs to go through the same gates as a normal deployment (audit trail, sanity checks, automated tests).

**Automated rollback:** The pipeline can be extended to trigger a rollback automatically if the `deploy` or `test` job fails. This is done by adding an `on-failure` step at the end of the relevant job that runs `kubectl rollout undo`. This keeps the cluster in a known-good state without manual intervention, at the cost of a slightly longer pipeline.

### Deployment strategies

Standard Kubernetes deployment strategies apply to webMethods integration microservices without modification.

- **Rolling update** — the default Kubernetes strategy. Pods are replaced incrementally: new pods are started before old ones are terminated, keeping the service available throughout the update. This is what this repository uses.
- **Blue/green** — two full deployments coexist (`blue` = current, `green` = new). Traffic is switched atomically by updating the Service selector. Rollback is instant: switch the selector back. Requires double the resources during the transition.
- **Canary** — the new version receives a small fraction of traffic alongside the current version. Useful for validating behaviour under real load before a full rollout. Typically implemented via ingress traffic splitting or a service mesh.

All of these strategies are applicable to webMethods integration microservices — with one important caveat: **they assume that version N+1 can run concurrently with version N**. This is not always the case. If a new version introduces a breaking change to a shared data schema, a message format, or a queue contract, running both versions simultaneously will cause inconsistencies. It is the responsibility of the development team to assess compatibility before choosing a deployment strategy. When in doubt, a blue/green switch with a maintenance window is safer than a rolling update.

### Repository configuration

The following variables and secrets must be configured at the GitHub repository level before running the workflow.

**Variables** (`Settings > Secrets and variables > Actions > Variables`):

| Variable | Description |
|---|---|
| `REGISTRY_URL` | Hostname of the target container registry (e.g. `ghcr.io/your-org`) |
| `BASE_REGISTRY_URL` | Hostname of the base image registry (`containers.webmethods.io`) |
| `IMAGE_NAME` | Image name, without registry prefix (e.g. `msr-order-management`) |
| `MAJOR_VERSION` | Major version number (e.g. `1`) |
| `MINOR_VERSION` | Minor version number (e.g. `0`) |
| `KUBE_NAMESPACE` | Kubernetes / OpenShift namespace to deploy into |
| `DEPLOYMENT_NAME` | Name of the Kubernetes Deployment (and Secret, Ingress, Route) |

**Secrets** (`Settings > Secrets and variables > Actions > Secrets`):

| Secret | Description |
|---|---|
| `REGISTRY_USERNAME` | Username for the target container registry |
| `REGISTRY_PASSWORD` | Password / token for the target container registry |
| `BASE_REGISTRY_USERNAME` | Username for `containers.webmethods.io` |
| `BASE_REGISTRY_PASSWORD` | Password / token for `containers.webmethods.io` |
| `WPM_TOKEN` | Token for `packages.webmethods.io`, used by `wpm` during the image build |
| `KUBE_CONFIG` | Full content of the kubeconfig file for the target cluster |
