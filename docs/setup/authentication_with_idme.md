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

Start the `vets-api` rails server:
```
bundle exec rails s
```

1. Curl or browse to `http://localhost:3000/v0/sessions/authn_urls`
2. The response takes the form:
```
{
  "mhv":"<MHV_URL>",
  "dslogon":"<DSLOGON_URL>",
  "idme":<IDME_URL>
}
```
Copy and paste the `idme` URL into your browser.

3. Enter ID.me credentials using one of our 
    [test accounts](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/MVI%20Integration/reference_documents/mvi_users_s1a.csv). If you do not have access to the vets.gov-team repository, you may optionally create your own account with ID.me.
  - **Note**: Accounts created on the https://api.id.me/ ID.me site are
    separate from accounts created in the https://api.idmelabs.com sandbox.
4. The browser should get redirected to the SAML relay URL of http://localhost:3001/auth/login/callback?token=abcd1234-efgh5678
  The browser will display `Page Not Found`, but that's normal.
  - **Note**: If `vets-website` were also running locally on `3001`, it would render properly
5. Copy the token value and attempt the following curl commands:

```
curl --header "Authorization: Token token=<TOKEN_VAL>" localhost:3000/v0/welcome

# Expected response:
# {"message":"You are logged in as vets.gov...@gmail.com"}
```

A valid JSON response means you succeeded!
