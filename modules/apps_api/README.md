# Apps Api

## Endpoints
Publically this app exposes an `#index` method for returning all applications in the directory, a `#show` endpoint to get an individual application, and a `#scopes` method for seeing what scopes a service category will ask for. The scopes information is used for the Application Directory internally but is listed in the README since it is also a GET route. The routes for each are shown below. If the `APP_NAME` contains whitespace, replace each whitespace character with `%20` in the URL. See examples below.
All other endpoints inside `apps_api` require an api_key and are for internal use only.

```
# index
GET /v0/apps
# show
GET /v0/apps/{APP_NAME}
  EX:
  GET /v0/apps/Apple%20Health
#scopes
GET /v0/apps/scopes/{SERVICE_CATEGORY}
  EX:
  GET /v0/apps/scopes/health
```

For internal usage, there is a [CLI](https://github.com/department-of-veterans-affairs/app_directory_cli) available to allow for interacting with the `#create`, `#update`, and `#destroy` methods. For syntax and usage of that CLI, see the linked repo. Non-GET methods used in this CLI require an api_key for the environment you are trying to make changes in.

## Sentry
All `get` endpoints are tracked in Sentry using `sentry-ruby`. The only controller tracked is `VO::AppsController`, which handles all read-only inputs and attaches a valid api token before redirecting to the `AppsApi::DirectoryController`. There are no alerts created for this controller, but they could be spun up as needed. `VO::AppsController` is located at `app/controllers/vo/apps_controller.rb`.

