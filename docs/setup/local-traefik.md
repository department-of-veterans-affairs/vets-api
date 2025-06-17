# Running Traefik Locally (native Vets API)

This guide shows how to spin up a production-like Traefik container on your local machine, routing all traffic through it to your Vets API instance. No YAML configuration files are required beyond the generated dynamic file.

> **Note:** When using Traefik with [OpenResty](local-openresty.md) in a multi-tier setup, we recommend running Traefik on port 8081 (using `--port 8081`). OpenResty will automatically detect Traefik on this port and forward traffic accordingly.

---

## Prerequisites

* Docker installed and running.
* Vets API running locally on port **3000** (e.g. via `bin/prod`).

---

## Usage

```bash
# Default port 80 (not recommended when using with OpenResty)
bin/local-traefik

# Recommended when using with OpenResty
bin/local-traefik --port 8081

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

## Using with OpenResty

For a multi-tier proxy setup:

1. Start Traefik on port 8081:
   ```bash
   bin/local-traefik --port 8081
   ```

2. Then run OpenResty (which will automatically detect Traefik):
   ```bash
   bin/local-openresty
   ```

This creates a proxy chain where:

- External requests → OpenResty (port 80) → Traefik (port 8081) → Vets API (port 3000)

You can also specify a different port for Traefik and tell OpenResty where to find it:
```bash
bin/local-traefik --port 9000
bin/local-openresty --traefik-port 9000
```

This setup can be useful for testing configurations that mirror our production environments with multiple proxy layers.
