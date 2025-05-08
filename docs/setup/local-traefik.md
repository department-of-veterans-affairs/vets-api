# Running Traefik Locally (native Vets API)

This guide shows how to spin up a production-like Traefik container on your local machine, routing all traffic through it to your Vets API instance. No YAML configuration files are required beyond the generated dynamic file.

---

## Prerequisites

* Docker installed and running.
* Vets API running locally on port **3000** (e.g. via `bin/prod`).

---

## Usage

```bash
# Defaults: port 80
bin/local-traefik

# Specify a custom port and Traefik version
bin/local-traefik --port 8081 --version 2.8.7
```

## Flags

* `--port PORT`  Host port to bind Traefik’s `web` entryPoint (default: `80`).
* `--version VERSION`  Traefik Docker image version to use.
* `-h`, `--help`  Show help message.

---

## How It Works

1. **Generate configuration** — If `tmp/traefik-dynamic.yml` does not exist, the script creates it:

   ```yaml
   http:
     routers:
       vets-api:
         rule: PathPrefix(`/`)
         entryPoints:
           - web
         service: vets-api

     services:
       vets-api:
         loadBalancer:
           servers:
             - url: "http://host.docker.internal:3000"
   ```

   > **Note for Linux users:** The `host.docker.internal` hostname is not natively supported on Linux. To enable this functionality, you may need to configure your Docker setup to use the host network mode or create a custom bridge network. Refer to the [Docker documentation](https://docs.docker.com/network/) for more details.
2. **Start Traefik** — Runs the official Traefik image with flags to load the dynamic config:

   ```bash
   docker run --rm --name traefik-local \
     -p <PORT>:80 \
     -v "$(pwd)/tmp/traefik-dynamic.yml":/etc/traefik/dynamic.yml:ro \
     traefik:<VERSION> \
       --entryPoints.web.address=":80" \
       --providers.file.filename="/etc/traefik/dynamic.yml"
   ```

3. **Route traffic** — Any request to `http://localhost:<PORT>/…` is proxied through Traefik to your local Vets API.
