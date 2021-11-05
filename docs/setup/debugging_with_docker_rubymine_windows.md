### Debugging in Docker, useful for windows developers.

UNSUPPORTED. These are community-generated steps. YMMV.
These instructions assume you are using RubyMine, an IDE from JetBrains. If you are using another IDE, like VS code, expect to to work through some issues.

You can get it here:
https://www.jetbrains.com/ruby/

When developing with Windows you need to ensure that your clone pulled down all your files with unix style line endings.
To check, from git bash use the *file* utility:
```
$ file docker-compose.yml
docker-compose.yml: ASCII text
```
The above output is good. If you see:
```
$ file docker-compose.yml
docker-compose.yml: ASCII text, with CRLF line terminators
```
That is bad.  You will need to re-clone and ensure you pass the test above.  There are many resources on the web that can help with this, here is one that can help:

https://www.cylindric.net/git/force-lf

The main readme describes setting up (touching) your certs. Make sure you do that.

###API keys:
go to:  https://developer.va.gov/ and click the 'Request an API key' button. You will receive an email with your API key that you will use in Postman as well as in the setup in settings.local.yml below.

###.env File
Create a .env file in Rails root and add the following code:
```
VETS_API_USER_ID=993
```

###Settings.local.yml
Create a settings.local.yml file. Here is a sample.

```
# betamocks:
  # For NATIVE installation
  # The relative path to department-of-veterans-affairs/vets-api-mockdata
  # cache_dir: ../vets-api-mockdata

binaries:
  # you can specify a full path in settings.local.yml if necessary
  pdfinfo: pdfinfo
  pdftk: pdftk
  clamdscan: ./bin/fake_clamdscan
saml:
  authn_requests_signed: false
redis:
  host: localhost
  port: 6379
  app_data:
    url: redis://redis:6379
    # secondary_url: redis://localhost:6378
  sidekiq:
    url: redis://redis:6379

lighthouse:
  api_key: <your api key here>
  facilities:
    url: https://sandbox-api.va.gov
    api_key: <your api key here>

forms:
  url: https://sandbox-api.va.gov/services/va_forms/v0/
  mock: false

va_forms:
  drupal_username: <Drupal Username>
  drupal_password: <Drupal Password>
  drupal_url: https://prod.cms.va.gov

database_url: 'postgis://postgres:password@postgres:5432/vets_api_development?pool=4'
test_database_url: 'postgis://postgres:password@postgres:5432/vets_api_test?pool=4'

docker_debugging:
  set_up_db: false
  hang_around: false

```
The main docker file has the following line:
```
RUN freshclam --config-file freshclam.conf
```
Commenting out this line can save you a lot of time in the initial build if you are using fake clamscan.

Now it is time to do your initial build. You need to do this before configuring RubyMine because the image must be built in order for RubyMine to be able to scan it for gems.
Run following from Rails root (this will cause the PUMA server to come up as well):
```
touch docker_debugging
```
Now build the Docker image and bring up Puma via:
```
docker-compose up
```
This will be time-consuming the first time that you do this. When you see the following you are up and running:
```
vets-api_1  | * Listening on tcp://0.0.0.0:3000
```

Eventually Puma will come up and you can hit an endpoint in a browser at:
http://localhost:3000/v0/status

Verify that it returns:
```
{"git_revision":"MISSING_GIT_REVISION","db_url":null}
```
Now we need to configure RubyMine for remote debugging so bring the Docker containers down:
```
docker-compose down
```

Open Ruby mine and open the settings page (File -> Settings -> Ruby SDK and Gems).

![GitHub Logo](./images/RubyMine-settings.png)

Select '+' -> 'new remote'. Choose the 'Docker Compose' radio button and 'vets-api' for the service.

![GitHub Logo](./images/RubyMine-configure-remote-docker.png)

Now we are ready to set a breakpoint and debug in RubyMine via the Docker container.

Run -> debug... -> edit configurations 
Select '+' to add a new rails configuration. Name the debug configuration (VetsApi Docker) and accept the defaults.

![GitHub Logo](./images/RubyMine-debug-config.png)

Set a breakpoint in the AdminController.

![GitHub Logo](./images/RubyMine-AdminController-breakpoint.png)

Now, run the following endpoint and ensure that the breakpoint is hit:

http://localhost:3000/v0/status

Debugging in RubyMine ONLY brings up PUMA. So, if you need to run sidekiq you will need to log into the container using the bash scripts and run commands such as:

```
foreman start -m job=1,clamd=0,freshclam=0
``` 

###Interacting with the shell:
Create the following scripts and run them from a GitBash terminal. They can be placed wherever you want as they are used to connect the vets-api Docker container. 

**go.bash** (connects as vets-api user)
```
#!/usr/bin/bash
winpty docker exec -it vets-api_vets-api_1 bash
```

**rgo.bash** (connects as root user)
```
#!/usr/bin/bash
winpty docker exec -u 0 -it vets-api_vets-api_1 bash
```

Allows you to interact with the application from the shell like:
- `rake lint`
- `rails console`

For more details see:
[native instructions](docs/setup/running_natively.md)

######Viewing swagger docs

```
git clone https://github.com/department-of-veterans-affairs/developer-portal
```

Create a .env.local file in developer-portal root:
```
PORT=3001
REACT_APP_VETSGOV_SWAGGER_API=http://localhost:3000
REACT_APP_DEVELOPER_PORTAL_SELF_SERVICE_URL=http://localhost:3000
REACT_APP_SALESFORCE_ENV=VICDEV
```

Run:
- npm install
- npm start

Set up your SSH keys:
Follow these instructions for generating and setting up your SSH public and private keys.

https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/internal-tools.md#creating-an-ssh-keypair-in-windows

Once these keys are generated you will need to request environment access.

https://github.com/department-of-veterans-affairs/va.gov-team/issues/new?assignees=&labels=external-request%2C+operations&template=Environment-Access-Request-Template.md&title=Access+for+%5Bindividual%5D



