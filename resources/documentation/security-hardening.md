# Security Hardening

## Headless microservices

In a microservices integration architecture, integration microservices should be **headless**: they expose only the interfaces required for their integration function (API endpoints, queues, file drop directories) and nothing else. The MSR admin console should not be reachable from outside the cluster in any non-development environment.

Removing external access to the admin console is a significant security gain in itself. The console provides full administrative access to the runtime — package management, adapter configuration, flow debugging, user management. Keeping it off the network eliminates an entire attack surface. Configuration as code via `application.properties` removes the operational need for it: there is nothing to do in the console that cannot be done through a deployment pipeline.

The one legitimate exception is **monitoring and replay**. When operators need to inspect service executions or replay failed flows, a dedicated monitoring microservice — running WmMonitor and exposing its UI — is the correct pattern. Integration microservices remain headless; only the monitoring microservice exposes a UI, optionally protected by an IdP or LDAP. See [webMethods Monitoring](webmethods-monitoring.md) for details on this architecture.

---

## Two routes, two ingresses — only one belongs in production

This repository's example exposes two separate network paths, implemented as two Kubernetes Services, two Ingresses (or two Routes on OpenShift):

| Resource | Target port | Purpose |
|---|---|---|
| `msr-order-management` / `msr-order-management` | `5555` (HTTP) | Admin console and full MSR access |
| `msr-order-management-api` / `msr-order-management-api` | `8843` (HTTPS) | Restricted API access only |

**The route and ingress pointing to port `5555` should not exist in production.** It is present in this repository for development convenience only — it is what allows the admin console to be reached during local testing and demonstrations.

In production, only the API route/ingress should be kept. All external traffic reaches the MSR exclusively through port `8843`.

---

## The API port: HTTPS with a dedicated keystore, deny by default

Port `8843` is a custom HTTPS listener defined in the `demoOrderManagement` package (`config/listeners.cnf`). It is configured with a dedicated keystore (`API_KEYSTORE`, a PKCS12 file mounted from a Kubernetes Secret) and operates on a **deny-by-default** access control model: all services are blocked unless explicitly whitelisted.

The whitelist is limited to what is strictly necessary for the API to function:

```xml
<record name="HTTPSListener@8843" javaclass="com.wm.util.Values">
  <value name="default">exclude</value>
  <record name="nodes" javaclass="com.wm.util.StringSet">
    <list name="elements">
      <value>demoOrderManagement.services</value>
      <value>wm.server:connect</value>
      <value>wm.server:disconnect</value>
      <value>wm.server:ping</value>
      <value>wm.server:noop</value>
      <value>wm.server.tx:start</value>
      <value>wm.server.tx:execute</value>
      <value>wm.server.tx:end</value>
      <value>wm.server.tx:restart</value>
      <value>wm.server:getClusterNodes</value>
      <value>wm.server:getServerNodes</value>
      <value>wm.server.csrfguard:isCSRFGuardEnabled</value>
      <value>wm.server.csrfguard:getCSRFSecretToken</value>
      <value>wm.server.csrfguard:replaceSpecialCharacters</value>
    </list>
  </record>
</record>
```

The `default` is `exclude`: any service not in this list is unreachable through this port. Notably, the admin console and all administrative services are absent from the whitelist — they are inaccessible through port `8843`. Only `demoOrderManagement.services` (the business API) and a small set of runtime services required for session handling and transaction management are allowed through.

The keystore is referenced in `application.properties` and its certificate is mounted from a Kubernetes Secret at startup:

```properties
keystore.API_KEYSTORE.ksLocation=/certs/api/api-keystore.p12
keystore.API_KEYSTORE.ksType=PKCS12
keystore.API_KEYSTORE.ksPassword=$secret{API_KEYSTORE_PASSWORD}
keystore.API_KEYSTORE.keyAlias.sttlab.local.keyAliasPassword=$secret{API_KEYSTORE_PASSWORD}
```

---

## TLS termination modes

Three TLS termination modes are available at the ingress/route level. They differ in where decryption happens and what is visible inside the cluster.

| Mode | Where TLS is terminated | Traffic inside the cluster | Requires MSR keystore |
|---|---|---|---|
| **Edge** | Ingress / Route | Plain HTTP | No |
| **Passthrough** | Inside the pod (MSR) | Encrypted end-to-end | Yes |
| **Re-encrypt** | Ingress / Route, then re-encrypted | Encrypted (separate certificate) | Yes |

**Edge** is the simplest to set up: the ingress controller handles the certificate, and the MSR receives plain HTTP. The downside is that traffic is unencrypted between the ingress and the pod — inside the cluster, but still traversing shared network infrastructure.

**Passthrough and re-encrypt are more rigorous from a security standpoint.** With passthrough, the ingress forwards the encrypted stream as-is and has no visibility into it; TLS is terminated exclusively inside the MSR pod. With re-encrypt, the ingress decrypts and re-encrypts — traffic is always encrypted on the wire, and the pod-side certificate can be managed independently of the external-facing one. Both modes ensure that traffic is never in plaintext inside the cluster.

### What this repository does

This repository illustrates both modes:

- The **admin ingress/route** uses **edge termination** — acceptable for development, where convenience matters more than strict security. The ingress handles the certificate; the MSR receives plain HTTP on port `5555`.
- The **API ingress/route** uses **passthrough** — the ingress forwards encrypted traffic directly to port `8843`, where the MSR terminates TLS using the `API_KEYSTORE` keystore. End-to-end encryption is preserved.

In Kubernetes (NGINX ingress), passthrough for the API ingress is enabled via the `backend-protocol` annotation:

```yaml
# ingress.yaml — API ingress
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

On OpenShift, the Route sets `termination: passthrough` directly:

```yaml
# route.yaml — API route
tls:
  termination: passthrough
  insecureEdgeTerminationPolicy: Redirect
```

### Enabling passthrough at the ingress controller level

Passthrough is not always enabled by default and may require explicit configuration at the ingress controller or router level.

**NGINX Ingress Controller** — TCP passthrough requires the `--enable-ssl-passthrough` flag on the controller. Without it, the `backend-protocol: HTTPS` annotation is silently ignored and the ingress falls back to edge termination. The flag is typically set in the controller's deployment arguments:

```yaml
args:
  - --enable-ssl-passthrough
```

**OpenShift Router** — passthrough is supported natively and requires no additional configuration. The `termination: passthrough` field in the Route spec is sufficient.

In both cases, passthrough bypasses the ingress controller's ability to inspect or manipulate the traffic — which is precisely the point, but also means that ingress-level features such as path-based routing, header manipulation, and WAF rules are unavailable for passthrough routes. This is an acceptable trade-off for an API port that is already restricted by the MSR's own deny-by-default access control.

### cert-manager

[cert-manager](https://cert-manager.io) is the de facto standard for certificate lifecycle management in Kubernetes. It automates issuance and renewal from a wide range of certificate authorities — Let's Encrypt, HashiCorp Vault, internal PKIs via ACME or CMCA — and stores the resulting certificates as Kubernetes Secrets, which is exactly how the manifests in this repository already consume them.

This repository manages certificates manually, but there is no obstacle to using cert-manager here — quite the opposite. In organisations where cloud-native practices are mature, cert-manager is very likely already in place. Adopting it for MSR deployments requires minimal changes: annotate the relevant Ingresses or Secrets with the appropriate cert-manager annotations and remove the manual certificate management. The rest of the deployment is unchanged.

For edge and re-encrypt ingresses, cert-manager handles the ingress-side certificate automatically via the `cert-manager.io/cluster-issuer` annotation. For passthrough routes (where the certificate is terminated inside the MSR pod), cert-manager can still manage the lifecycle of the keystore secret — it issues the certificate and stores it as a Kubernetes Secret, which is then mounted into the container at the expected path.

---

## Restricting the Administrator account

The built-in `Administrator` account has unrestricted access to the MSR. Its password must be set via `application.properties` — never hardcoded, always injected from a secret:

```properties
user.Administrator.password=$secret{ADMIN_PASSWORD}
```

For API access, dedicated non-admin users should be created and assigned to appropriate groups. The `application.properties` mechanism supports this directly:

```properties
# Create a non-admin user for API consumers
user.tester.password=$secret{TESTER_PASSWORD}

# Assign it to the Everybody group (non-admin)
group.Everybody.users=tester
```

This is illustrated in the ConfigMap at [`resources/kubernetes/config-map.yaml`](../../resources/kubernetes/config-map.yaml). The `tester` user is a member of `Everybody` only — it has no administrative privileges and cannot reach the admin console or any administrative service.

In production, API calls should be made under a dedicated non-admin account. The `Administrator` account should not be used for runtime API traffic, and its password should be rotated and kept in a secrets manager rather than shared.
