# Deployment Information

## When merged pr is deployed to various environments
Merged work is automatically deployed to all environments.
Below details at what point in the process these auto-deployments will occur.

dev + staging + sandbox = immediately after code is merged and passes ci
production = once a day at 1pm CT

## Additional manual work
Specific Jenkins builds are required to be manually run if deploying any database migrations.
Below builds need to be executed after code has been deployed to each environment.

dev = http://jenkins.vfs.va.gov/job/deploys/job/vets-api-server-vagov-dev-post-deploy/build
staging = http://jenkins.vfs.va.gov/job/deploys/job/vets-api-server-vagov-staging-post-deploy/build
sandbox = http://jenkins.vfs.va.gov/job/deploys/job/vets-api-server-vagov-sandbox-post-deploy/build
production = http://jenkins.vfs.va.gov/job/deploys/job/vets-api-server-vagov-prod-post-deploy/build

Note: May require waiting up to an hour after deployment has occurred.
