
Authentication with IDme now happens via SessionStore cookie. The epic outlining that work is [here](https://github.com/department-of-veterans-affairs/vets.gov-team/issues/14225) 
---
_Prior approach, deprecated in favor of SessionStore cookie_

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

### Enabling Crypto for Localhost Authentication

1. Copy the localhost [certificate][certificate] to `config/certs/vetsgov-localhost.crt`
2. Copy the localhost [key][key] to `config/certs/vetsgov-localhost.key`
3. Enable signed authentication requests:

```yaml
# settings.local.yml
saml:
  authn_requests_signed: true
```
   
[certificate]: https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/TBD_LOCATION/vetsgov-localhost.key
[key]: https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/TBD_LOCATION/vetsgov-localhost.key


#### Additional Info 

The `vets-api` rails server requires that a SAML key & cert file exist in order to start up - which is why the recommended approach is to `touch` empty key & cert files. 

For the `saml-rp.vetsgov.localhost` profile, if an AuthNRequest is not signed, then ID.me skips this signature validation. If a signature is present however, ID.me will validate that signature and return an error if that signature is incorrect. Additionally, AuthNResponses are not encrypted.

For all other environments `dev`, `staging` & `prod` - AuthNRequests require a signature and AuthNResponses are encrypted.


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

1. Curl or browse to `http://localhost:3000/sessions/idme/new`
2. The response takes the form:
```
{
  "url": "https://very.long.url/with/a/bunch/of/crypto/stuff"
}
```
Copy and paste the URL into your browser.

3. Enter ID.me credentials using one of our 
    [test accounts](https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Identity/MVI%20Integration/reference_documents/mvi_users-dev.md). If you do not have access to the vets.gov-team repository, you may optionally create your own account with ID.me.
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
