# Apps Api

This project uses MIT-LICENSE.

## Endpoints
Publically this app exposes an `#index` method for returning all applications in the directory, and a `#show` endpoint to get an individual application. The routes for each are shown below. If the `APP_NAME` contains whitespace, replace each whitespace character with `%20` in the URL.

```
# index
GET /services/apps/v0/directory
# show
GET /services/apps/v0/directory/{APP_NAME}
  EX:
  GET /services/apps/v0/directory/Apple%20Health

```

For internal usage, there is a (CLI)[https://github.com/department-of-veterans-affairs/app_directory_cli] available to allow for interacting with the `#create`, `#update`, and `#destroy` methods. For syntax and usage of that CLI, see the linked repo.
In order to access these methods, you must pass the proper secret in the `Authorization` header. The credstash keys where these secrets are stored are referenced in the `devops` repo under `{ENV}-settings.local.yml.j2`. See repo [here](https://github.com/department-of-veterans-affairs/devops/tree/master/ansible/deployment/config/vets-api).

