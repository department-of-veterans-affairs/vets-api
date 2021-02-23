# Apps Api

## Endpoints
Publically this app exposes an `#index` method for returning all applications in the directory, a `#show` endpoint to get an individual application, and a `#scopes` method for seeing what scopes a service category will ask for. The scopes information is used for the Application Directory internally but is listed in the README since it is also a GET route. The routes for each are shown below. If the `APP_NAME` contains whitespace, replace each whitespace character with `%20` in the URL. you can also pass the `APP_NAME` as the `search_term` query param. See examples below.
All other endpoints inside `apps_api` require an api_key and are for internal use only.
```
# index
GET /v0/apps
# show
GET /v0/directory/{APP_NAME}
  EX:
  GET /v0/directory/Apple%20Health
  GET /v0/directory/?search_term='Apple Health'
#scopes
GET /v0/directory/scopes/{SERVICE_CATEGORY}
  EX:
  GET /v0/directory/scopes/health
```

For internal usage, there is a [CLI](https://github.com/department-of-veterans-affairs/app_directory_cli) available to allow for interacting with the `#create`, `#update`, and `#destroy` methods. For syntax and usage of that CLI, see the linked repo. Non-GET methods used in this CLI require an api_key for the environment you are trying to make changes in.

