# demoOrderManagement: webMethods Integration microservice showcase

## Table of Contents

1. [Introduction](#introduction)
2. [Content](#content)
3. [Scenario Architecture](resources/documentation/architecture.md)
4. [Cloud-native webMethods Platform](resources/documentation/cloud-native-platform.md)
5. [Development](resources/documentation/development.md)
6. [Image Build](resources/documentation/image-build.md)
7. [External Configuration](resources/documentation/external-configuration.md)
8. [Testing using Docker Compose](resources/documentation/testing-docker-compose.md)
9. [Deployment in Kubernetes (and OpenShift)](resources/documentation/deployment-kubernetes.md)
10. [CI/CD](resources/documentation/cicd.md)
11. [webMethods upgrades](resources/documentation/webmethods-upgrades.md)
12. [Observability](resources/documentation/observability.md)
13. [webMethods Monitoring](resources/documentation/webmethods-monitoring.md)
14. [Breaking the Monolith](resources/documentation/breaking-the-monolith.md)
15. [Autoscaling](resources/documentation/autoscaling.md)
16. [Pre-baked vs Fried](resources/documentation/prebaked-vs-fried.md)
17. [Recommendations](resources/documentation/recommendations.md)

---

## Introduction

This repository provides a reference implementation of a **webMethods Integration Server microservice**, demonstrating a half-flow architecture built around a canonical data model.

The scenario covers an **order reception flow**, where incoming orders are received through multiple inbound channels — JMS messaging, REST/HTTP API, and file-based ingestion — and normalized into a canonical format before being forwarded downstream. This represents the first half of the integration flow (inbound normalization).

The goal is to illustrate integration best practices in a containerized, cloud-native context using webMethods tooling.

## Content

This repository contains a ready-to-deploy webMethods Integration Server package, along with all the supporting resources needed to build, run, and operate it in various environments.

```
.
├── Dockerfile                          # Container image definition
├── Makefile                            # Automation helpers (build, deploy, test...)
└── resources/
    ├── api/                            # Swagger definition of the Orders API
    ├── databases/                      # DDL script to provision the database schema
    ├── docker-compose/                 # Docker Compose stack for local testing
    ├── docker-compose-dev/             # Docker Compose stack for local development
    ├── kubernetes/                     # Kubernetes manifests (Deployment, Service, HPA, Ingress, etc.)
    ├── samples/                        # Sample input data (e.g. orders.csv)
    ├── tests/                          # Shell script helpers for manual API testing
    └── documentation/                  # Extended documentation (this doc)
```

The package can be deployed directly into a webMethods Integration Server instance once the required resources (JDBC connection, JMS connection aliases, etc.) are configured. Refer to the [External Configuration](resources/documentation/external-configuration.md) section for details.
