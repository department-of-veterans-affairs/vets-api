# Running OpenResty Locally (native Vets API)

This guide shows how to spin up an OpenResty container on your local machine as a reverse proxy for your Vets API instance. OpenResty is a platform based on NGINX and LuaJIT.

OpenResty can be used either directly as a reverse proxy to your Vets API or in conjunction with Traefik, where OpenResty serves as the primary entry point and forwards requests to Traefik, which then routes to your Vets API.

---

## Prerequisites

* Docker installed and running.
* Vets API running locally on port **3000** (e.g. via `bin/prod`).
* Optionally: Traefik running locally on port **8081** (see [Running Traefik Locally](local-traefik.md)).

---

## Usage

```bash
# Defaults: port 80, automatically detecting Traefik on port 8081
bin/local-openresty

# Specify a custom port for OpenResty
bin/local-openresty --port 8080

# Specify a custom Traefik port to connect to
bin/local-openresty --traefik-port 9000

# Specify both custom ports and OpenResty version
bin/local-openresty --port 8080 --traefik-port 9000 --version 1.21.4.1-0-focal
```

## Flags

* `--port PORT`  Host port to bind OpenResty to (default: `80`).
* `--traefik-port PORT`  Port where Traefik is expected to be running (default: `8081`).
* `--version VERSION`  OpenResty Docker image version to use (default: `1.25.3.1-0-jammy`).
* `-h`, `--help`  Show help message.

The script automatically detects whether Traefik is running on the specified port and configures itself accordingly.

---

## How It Works

1. **Verify API is running** — The script checks if your Vets API is running on localhost:3000.

2. **Auto-detect Traefik** — The script automatically checks if a service (likely Traefik) is running on port 8081 (or the port specified with `--traefik-port`) and configures itself accordingly:
    - If no service is detected: Uses direct mode (OpenResty → API)
    - If a service is detected: Uses Traefik mode (OpenResty → Traefik → API)

3. **Generate configuration** — If `tmp/openresty-local.conf` does not exist, the script creates an NGINX configuration file:

   ```nginx
   worker_processes auto;
   error_log /dev/stderr info;
   pid /tmp/nginx.pid;

   events {
     worker_connections 1024;
   }

   http {
     access_log /dev/stdout combined;
     
     upstream vets_api {
       server host.docker.internal:8081;  # Points to Traefik, or 127.0.0.1:3000 in direct mode
     }

     server {
       listen 80;
       server_name localhost;

       location / {
         proxy_pass http://vets_api;
         proxy_set_header Host $host;
         proxy_set_header X-Real-IP $remote_addr;
         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
         proxy_set_header X-Forwarded-Proto $scheme;
       }
     }
   }
   ```

   > **Note for Linux users:** The `host.docker.internal` hostname is not natively supported on Linux. The script adds `--add-host=host.docker.internal:host-gateway` to the Docker run command, but you may need additional configuration depending on your setup.

4. **Start OpenResty** — Runs the official OpenResty Docker image with the generated configuration:

   ```bash
   docker run --rm \
     -p "$PORT:80" \
     -v "$(pwd)/$OPENRESTY_CONF:/usr/local/openresty/nginx/conf/nginx.conf:ro" \
     --add-host=host.docker.internal:host-gateway \
     --name vets-api-openresty \
     openresty/openresty:$VERSION
   ```

5. **Route traffic** — Any request to `http://localhost:<PORT>/…` is proxied through OpenResty to your local Vets API, either directly or via Traefik depending on what was detected.

## When to Use OpenResty and Traefik

- **OpenResty alone (auto-detected)** provides a lightweight NGINX-based reverse proxy with Lua scripting capabilities. Use this if you need to test custom NGINX configurations or Lua scripts without the Traefik layer.

- **OpenResty with Traefik** creates a multi-tier proxy setup where:
    1. OpenResty serves as the initial entry point, handling connections and potentially applying NGINX-specific optimizations or Lua scripts
    2. Traefik acts as the service router, managing dynamic routing rules and middleware

- **Traefik alone** provides a more production-like experience with modern features like automatic service discovery and middleware without the NGINX layer. Use this if you want a simplified setup closer to certain production environments.

This flexibility allows you to test various configurations that might mirror our production setup where we use both OpenResty and Traefik.
