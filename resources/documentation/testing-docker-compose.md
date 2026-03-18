# Testing using Docker Compose

Before pushing code or configuration to a remote Git repository, it is good practice to validate locally that the built image starts correctly and behaves as expected with its external configuration. Docker Compose provides a lightweight way to spin up the full stack — MSR, message broker, database — on a local machine and run end-to-end verification before any remote commit.

The `resources/docker-compose/` directory provides a ready-to-use stack for this purpose.

## Stack description

The compose stack (`resources/docker-compose/docker-compose.yml`) starts three services on a dedicated `wm` network:

| Service | Image | Description |
|---|---|---|
| `postgres` | `postgres:latest` | PostgreSQL database, exposed on port `15432` |
| `umserver` | `universalmessaging-server:11.1.2` | Universal Messaging broker, exposed on ports `19000` and `19200` |
| `msr` | The pre-built microservice image | MSR, exposed on the port defined by `DOCKER_PORT_NUMBER` (default `16666`) |

The MSR container mounts:
- `application.properties` — the external configuration file (from `resources/docker-compose/`)
- `./files` — the file polling directory, mapped to the MSR's `files/` directory

All sensitive values (passwords, connection parameters) are read from a `.env` file placed in `resources/docker-compose/`. This file is **not committed to Git** — copy `.env.example` and fill in the values for your environment:

```sh
cp resources/docker-compose/.env.example resources/docker-compose/.env
```

## Typical workflow

### 1. Build the image

```sh
make docker-build TAG=<image-tag>
```

Builds the microservice image locally using the `Dockerfile`. Requires the `WPM_TOKEN` environment variable to authenticate against the webMethods package registry. The `TAG` variable controls the image tag — if omitted, it defaults to the value defined in the `Makefile` (`latest`).

### 2. Start the stack

```sh
make docker-run TAG=<image-tag>
```

Starts the full compose stack (PostgreSQL + Universal Messaging + MSR) in detached mode. The `TAG` variable must match the tag used during the build so that the compose stack pulls the correct image. Alternatively, `TAG` can be set in the `.env` file to avoid repeating it on every command.

### 3. Follow the MSR logs

```sh
make docker-msr-logs
```

Tails the MSR container logs to verify startup and check for errors.

### 4. Run tests

Test the file inbound channel by dropping a sample CSV into the polling directory:

```sh
make docker-test-file
```

This generates a timestamped CSV file from `resources/samples/orders.csv` and copies it to `resources/docker-compose/files/incoming/`, where the file polling listener will pick it up.

Test the REST API by posting an order or listing existing orders:

```sh
make docker-test-api-post
make docker-test-api-list
make docker-test-api-list ORDER_ID=ORD-20240101-120000
```

### 5. Stop the stack

```sh
make docker-stop
```
