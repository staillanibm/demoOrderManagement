# Breaking the Monolith

A traditional webMethods Integration Server deployment tends to become a monolith over time: a single IS instance hosts dozens or hundreds of packages, covering unrelated functional domains, maintained by different teams, and deployed together as a single unit. Breaking this monolith into integration microservices requires deciding where to draw the boundaries.

The fundamental principle behind any decomposition is **cohesion**: a microservice should group things that change together, are deployed together, and are owned together. A boundary is well-drawn when crossing it is rare and deliberate — and poorly drawn when a single business change constantly requires touching multiple services simultaneously.

The ultimate goal is **agility at multiple levels**: faster and safer deployments (each service is independently deployable), better scalability (each service can be sized for its own load), clearer ownership (each service belongs to one team), and a codebase that can evolve without the entire organization moving in lockstep.

There is no single right answer on where to draw the lines — boundaries can be drawn along technical, functional, or organizational axes, and in practice the three are combined.

## Technical partitioning

Split by technical nature of the flows. Meaningful boundaries include:

- **API vs batch** — real-time API flows and batch/file-based processing have very different runtime characteristics (latency requirements, throughput, scaling behaviour). Separating them allows each to be sized and scaled independently.
- **Half-flow layers** — in a canonical half-flow architecture, the inbound normalization layer (receiving, mapping to canonical format, publishing to a queue) and the processing layer (consuming from the queue, persisting, routing) are natural candidates for separate microservices. This is the split illustrated in this repository.
- **Inbound vs outbound** — flows that receive data from external systems and flows that push data out can be separated, especially when they involve different protocols or SLA requirements.

This axis maps well to existing IS package structures and is often the easiest starting point. The risk is producing services that are technically clean but still share business logic — a change to a business rule may require touching multiple services.

## Functional partitioning

Split by business domain or capability, following **Domain-Driven Design (DDD)** principles. The key concept is the *bounded context*: a clearly delimited area of the business with its own model, its own language, and its own rules. Each bounded context becomes a natural candidate for a microservice — or a small cluster of microservices. For example:

- Order management
- Invoicing
- Shipping notifications

This is the recommended long-term target. Each microservice owns a coherent slice of business functionality end-to-end, regardless of the protocols involved. Boundaries are stable because they follow the business, not the technology — and the business changes less often than the technical stack.

## Criticality and compliance partitioning

Isolate flows by their risk profile, SLA requirements, or regulatory constraints. This axis is often overlooked but can be decisive:

- **Criticality** — a flow that is business-critical (payment processing, order confirmation) should not share a runtime with non-critical batch jobs. An incident on a low-priority flow should never bring down a critical one.
- **Security and compliance** — flows that handle sensitive data (PII, financial data, health records) may be subject to specific regulatory requirements (GDPR, PCI-DSS, HIPAA). Isolating them in a dedicated microservice makes it easier to apply stricter security controls, restrict network access, enforce audit logging, and scope compliance audits.

In practice this axis often refines a functional or organizational boundary: two flows in the same domain may still warrant separation if one carries regulated data and the other does not.

## Organizational partitioning

Follow team boundaries — Conway's Law states that the architecture of a system tends to mirror the communication structure of the organization that produces it. Rather than fighting this, use it deliberately: assign ownership of each microservice to a single team, and draw boundaries where team handoffs occur.

This axis is often the most pragmatic starting point in large organizations, as it reduces coordination overhead and gives teams clear ownership.

## In practice

These four axes are not mutually exclusive — a good decomposition typically satisfies all four simultaneously: each microservice is technically coherent, covers a well-defined functional scope, and is owned by a single team.

A few practical guidelines:

- **Start coarse, refine later.** It is easier to split a service further than to merge two services that have diverged. Avoid over-partitioning early.
- **Avoid shared packages between microservices.** Common framework packages belong in the corporate base image. Shared business logic is a sign that the boundary is drawn in the wrong place.
- **Each microservice should be independently deployable.** If deploying service A requires coordinating with service B, the boundary needs revisiting.
- **Data ownership matters.** Each microservice should own its data store. A shared database is a coupling point that limits independent evolution — even if it is sometimes a pragmatic compromise (see [webMethods Monitoring](webmethods-monitoring.md) for an acknowledged example).
