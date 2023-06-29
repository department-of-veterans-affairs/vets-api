# Deployment Information

## When merged pr is deployed to various environments
Merged work is automatically deployed to all environments.
Below details at what point in the process these auto-deployments will occur.

* dev + staging + sandbox = immediately after code is merged and passes ci
* production = once a day at 3pm ET

Schema migrations are handled by the db-migrate pods in EKS. The db-migrate pods execute the migration command before the server and worker pods are deployed. The migration will not succeed when deployments fail.
