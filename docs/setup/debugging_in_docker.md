### Debugging in Docker, useful for windows developers.

These instructions assume you are using RubyMine, an IDE from JetBrains.
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

Create a setting.local.yml file. Here is a sample. Yours must include the redis changes at a minimum.

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
```
The main docker file has the following line:
```
RUN freshclam --config-file freshclam.conf
```
Commenting out this line can save you a lot of time in the initial build if you are using fake clamscan.

Now it is time to do your initial build. You need to do this before configuring RubyMine because the image must be built in order for RubyMine to be able to scan it for gems.
Run following from Rails root (this will cause the PUMA server to come up as well):
```
touch startserver
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

######Interacting with the shell:
Execute a *docker ps*
```
$ docker ps
CONTAINER ID        IMAGE                       COMMAND                  CREATED             STATUS              PORTS
                                       NAMES
9d47b7f24e7c        vets-api:latest 
```
Note the container id '9d47b7f24e7c' for vets-api.
Executing (from git bash on windows)
```
$ winpty docker exec -it 9d47b7f24e7c bash
vets-api@9d47b7f24e7c:~/src$
```

Allows you to interact with the application from the shell like:
- `rake lint`
- `rails console`

For more details see:
[native instructions](docs/setup/running_natively.md)


