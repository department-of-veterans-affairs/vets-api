## Vets-API ID.me Certificate Setup
Many of the API's are protected by a session token from ID.me.  In order to obtain this token, one must perform authentication through ID.me.  This authentication flow only works of the ID.me certificates
are properly configured within vets-api.

The following environment variables must be set (see `application.yml.example`):
```
CERTIFICATE_FILE
KEY_FILE
```

For local development, ID.me has configured their sandbox with a cert that developers can share.

1. Download the [key and certificate files](https://github.com/department-of-veterans-affairs/platform-team/tree/master/identity/certificates)
1. Set the environment variables above to point to your local copies of the files

## Manually Testing ID.me Authentication Flow
Note the following two endpoints:
```
curl localhost:3000/v0/status  # does not require a session token
curl localhost:3000/v0/welcome # requires a session token
```

The default callback from ID.me is configured to go to `http://localhost:3001/auth/login/callback`, which is a front-end route in production. To test just the API locally, without running the vets-website server, start the vets-api server on port 3001:
```
bundle exec rails s -p 3001
```
1. Curl or browse to `http://localhost:3001/v0/sessions/new`
2. Copy and paste the ID.me URL into your browser.
3. Enter ID.me credentials (Create your ID.me account if you have not already done so.  **Note**: creating your account on the ID.me site (https://api.id.me/) is separate from the sandbox (https://api.idmelabs.com) or sign in with your username and password.)
4. The browser should get redirected to `Settings.saml.relay` (default: http://localhost:3001/auth/login/callback?token=abcd1234-efgh5678)
5. Copy the token value and attempt the following curl commands:

```
curl --header "Authorization: Token token=GvmkAW231VxGHkYxyppr2QQsi1D7PStqeiJXyyja" localhost:3001/v0/sessions/current
curl --header "Authorization: Token token=GvmkAW231VxGHkYxyppr2QQsi1D7PStqeiJXyyja" localhost:3001/v0/profile
```

A valid JSON response to either of these authenticated calls means you succeeded!
