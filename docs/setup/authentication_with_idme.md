## Vets-API ID.me Certificate Setup

Many of the APIs are protected by a session token from ID.me. In order to obtain
this token, one must perform authentication through ID.me. This authentication
flow requires that the ID.me certificates are properly configured within
`vets-api`.

The [README](../../README.md) contains instructions for installing a certificate
that will work for local development. If your setup differs from this, customize
the `config/settings.local.yml` file with suitable configuration. For example,

```yaml
saml:
  cert_path: /path/to/cert
  key_path: /path/to/key
```

See [config/settings.yml](config/settings.yml) for all of the configuration
options.

## Manually Testing ID.me Authentication Flow

Note the following two endpoints:

```
curl localhost:3000/v0/status  # does not require a session token
curl localhost:3000/v0/welcome # requires a session token
```

The default callback from ID.me is configured to go to
`http://localhost:3001/auth/login/callback`, which is a front-end route in
production. To test just the API locally, without running the vets-website
server, start by running the `vets-api` server on port 3001 with
`bundle exec rails s -p 3001`, then:

1. Curl or browse to `http://localhost:3001/v0/sessions/new`
2. Copy and paste the ID.me URL into your browser.
3. Enter ID.me credentials
  - Create your ID.me account if you have not already done so, or sign in with
    your username and password.
  - **Note**: Accounts created on the https://api.id.me/ ID.me site are
    separate from accounts created in the https://api.idmelabs.com sandbox.
4. The browser should get redirected to the SAML relay URL
  - Defaults to http://localhost:3001/auth/login/callback?token=abcd1234-efgh5678
5. Copy the token value and attempt the following curl commands:

```
curl --header "Authorization: Token token=foo" localhost:3001/v0/sessions/current
curl --header "Authorization: Token token=foo" localhost:3001/v0/profile
```

A valid JSON response to either of these authenticated calls means you succeeded!
