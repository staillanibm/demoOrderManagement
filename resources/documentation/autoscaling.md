# Autoscaling

One of the key benefits of deploying webMethods integration microservices on Kubernetes is access to native autoscaling. The **HorizontalPodAutoscaler (HPA)** automatically adjusts the number of running pods based on observed load, within configured bounds.

## This repository's example

The HPA in `resources/kubernetes/hpa.yaml` scales between 1 and 3 replicas, triggered when average CPU utilisation exceeds 90%:

```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 90
```

CPU is the simplest metric to start with and requires no additional instrumentation. It is a reasonable proxy for load in most API-driven flows.

## Going further with Prometheus metrics

CPU-based scaling is a blunt instrument. The MSR exposes a rich set of Prometheus metrics (see [Observability](observability.md)) that can serve as more meaningful autoscaling signals — for example, the number of active service threads, request queue depth, or JMS message backlog. Kubernetes supports custom and external metrics via adapters (e.g. [KEDA](https://keda.sh)), making it possible to scale directly on application-level indicators rather than infrastructure proxies.

## The stateless prerequisite

Autoscaling works smoothly for **stateless** microservices. Adding a pod is straightforward — the new instance is immediately ready to handle requests. Removing a pod is equally safe — there is no local state to lose.

This changes fundamentally when a microservice becomes **stateful** — for example when Client-Side Queueing (CSQ) is enabled (see [Recommendations](recommendations.md)). In that case, each pod holds a local buffer of outbound messages. Scaling down means terminating a pod that may still have undelivered messages in its local queue — a potential data loss scenario. Stateful deployments require significantly more care around scaling: scale-down policies must be conservative, draining must be handled explicitly, and in practice autoscaling is much harder to apply safely.

Keeping microservices stateless is therefore not just an architectural principle — it is a direct enabler of the operational flexibility that makes autoscaling practical.

## Batch workloads

Microservice partitioning combined with container orchestration brings an additional benefit for batch processing. Batch flows are typically resource-intensive — they require significant CPU and memory for the duration of their execution, and comparatively little outside of it. In a traditional ESB, the infrastructure must be sized to support peak batch load, and those resources remain allocated permanently regardless of whether a batch is actually running.

On Kubernetes, a batch integration can be packaged as a **Kubernetes Job**: a dedicated pod is scheduled for the duration of the batch, runs to completion, and the resources are released back to the cluster once it terminates. Those resources become immediately available to other workloads. This model aligns infrastructure cost with actual consumption — a meaningful operational improvement over the always-on ESB sizing model.
