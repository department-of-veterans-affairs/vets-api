# Flipper

## Description
Flipper is a gem used for managing unreleased features in vets-api by placing features behind "feature toggles" that can be enabled/disabled via the Flipper UI in each environment.

[Flipper Documentation](https://www.flippercloud.io/docs/introduction)
[Flipper UI Documentation](https://www.flippercloud.io/docs/ui)

## Developing with Flipper in Vets API
Please see the [Feature Toggles Guide](https://depo-platform-documentation.scrollhelp.site/developer-docs/feature-toggles-guide) in the Platform Docs for information on how we use Flipper in Vets API.

## Local Development on Vets API Flipper Implementation

By default, engineers will be authorized when developing locally. If you're a Platform Engineer working on the Flipper implementation, and need to mimic production authentication/authorization, read the following.

### Requirements

Add the following to your `settings.local.yml`
```yaml
flipper:
  github_organization: department-of-veterans-affairs
  github_team: <see below>
  github_oauth_key: <see below>
  github_oauth_secret: <see below>
```

`github_team` - to give yourself access, provide the id of a team that you belong to (i.e. `backend-review-group`). You can retrieve the id via the github API:
```
curl -H "Authorization: token <personal_access_token>" https://api.github.com/orgs/department-of-veterans-affairs/teams/backend-review-group
```

[Creating a Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

`github_oauth_key`/`github_oauth_secret` - These reference the Client ID and Client Secret for the associated Github OAuth App. There are separate apps for each app using github authentication (Flipper, Sidekiq, Coverband, etc) AND for each environment INCLUDING a Test App for use with localhost, `va.gov-flipper-oauth-local-test`. The credentials are stored in the parameter store under `/dsva-vagov/vets-api/local-dev/flipper/github-oauth-key` and `/github-oauth-secret`, respectively. 
