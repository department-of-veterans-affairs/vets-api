# IDP (CAVE) configuration

This document covers configuration for the CAVE IDP proxy endpoints (`/v0/cave*`) and `Idp::Client`.

## Settings keys

IDP settings live under `cave.idp`:

```yaml
cave:
  idp:
    base_url: ~
    timeout: ~
    mock: true
    hmac:
      key_id: ~
      secret: ~
```

- `base_url`: Base URL for the IDP API.
- `timeout`: Request timeout in seconds.
- `mock`: When `true`, `Idp.client` uses `Idp::MockClient` (outside production).
- `hmac.key_id`: Optional key identifier sent as `X-IDP-Key-Id`.
- `hmac.secret`: Shared secret used to sign outbound IDP requests.

## Environment variables

`Idp::Client` and `Idp.client` use the following env vars:

- `IDP_API_BASE_URL`: IDP API base URL.
- `IDP_API_TIMEOUT`: Timeout in seconds.
- `IDP_USE_LIVE`: If present, forces live client outside production.
- `IDP_HMAC_KEY_ID`: Optional HMAC key identifier for outbound signed requests.
- `IDP_HMAC_SECRET`: HMAC shared secret for outbound signed requests.

## Resolution order

For `Idp::Client` config:

1. Constructor args (`base_url`, `timeout`, `hmac_key_id`, `hmac_secret`)
2. `Settings.cave.idp.base_url` / `Settings.cave.idp.timeout` / `Settings.cave.idp.hmac.*`
3. `IDP_API_BASE_URL` / `IDP_API_TIMEOUT` / `IDP_HMAC_*`
4. Default timeout of `15`

Outbound identity/signature behavior:

- `Idp::Client` always forwards `X-IDP-User-Id` from the authenticated `current_user`.
- When `IDP_HMAC_SECRET` (or `cave.idp.hmac.secret`) is configured, requests are signed and include:
  - `X-IDP-Timestamp`
  - `X-IDP-Key-Id` (when configured)
  - `X-IDP-Signature` (HMAC SHA-256)

For client type (`Idp.client`):

1. Production: always live (`Idp::Client`)
2. `IDP_USE_LIVE` present: live
3. `Settings.cave.idp.mock`
  - `true` => `Idp::MockClient`
  - `false` => `Idp::Client`

## Local development

Use `config/settings.local.yml` to override local behavior, for example:

```yaml
cave:
  idp:
    base_url: https://idp-api.example.com
    timeout: 15
    mock: true
    hmac:
      key_id: idp-hmac-v1
      secret: your-shared-secret
```

To test the live client in development/test, either set `mock: false` or set `IDP_USE_LIVE=true`.

## Deployment (non-local and production)

Set environment-specific values in deployment config and parameter store/secrets.

- Vets API deployment config location (private repo):
  - `devops/ansible/deployment/config/vets-api/`
  - Environment templates include `dev`, `staging`, and `prod` settings files.
- Add or update these env vars per environment:
  - `IDP_API_BASE_URL`
  - `IDP_API_TIMEOUT`
  - `IDP_HMAC_KEY_ID`
  - `IDP_HMAC_SECRET`
- Keep production/staging `mock: false` and do not set `IDP_USE_LIVE` unless intentionally overriding behavior.

### Production checklist

1. Add/update `IDP_API_BASE_URL`, `IDP_API_TIMEOUT`, `IDP_HMAC_KEY_ID`, and `IDP_HMAC_SECRET` in production deployment config.
2. Confirm runtime settings resolve to the expected values in production pods.
3. Verify `/v0/cave*` requests can reach the IDP API and time out as expected.
4. Verify IDP receives `X-IDP-User-Id` and HMAC headers on all four routes.
