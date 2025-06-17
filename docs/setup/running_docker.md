# Running the app with Docker

First make sure to follow the common [base setup](https://github.com/department-of-veterans-affairs/vets-api/blob/master/README.md#Base%20setup).

## ClamAV Antivirus Configuration
### EKS
Prior to EKS, ClamAV (the virus scanner) was deployed in the same process as Vets API. With EKS, ClamAV has been extracted out into it’s own service. Locally you can see the docker-compose.yml config for clamav.

Note: Running clamav natively, as we did in Vets API master still needs to be configured. For the time being, please run via docker:

Please set the clamav intitalizer initializers/clamav.rb file to the following:

```ruby
if Rails.env.development?
  ENV['CLAMD_TCP_HOST'] = Settings.clamav.host
  ENV['CLAMD_TCP_PORT'] = Settings.clamav.port
end
```

### Mocking ClamAV Locally
There is an additional choice to "mock" a successful clamav response if you want to receive a quick scanning response for local development. If you choose this path, please set the clamav mock setting to true in the local settings.yml. This will mock the clamav response in the virus_scan code.

```ruby
clamav:
  mock: true
```

## Makefile

A Makefile provides shortcuts for interacting with the docker images.

You can see all of the targets and an explanation of what they do with:

```bash
make help
```

To run vets-api and its redis and postgres dependencies run the following command from within the repo you cloned
in the above steps.

```bash
make up
```

You should then be able to navigate to [http://localhost:3000/v0/status](http://localhost:3000/v0/status) in your
browser and start interacting with the API. Changes to the source in your local
directory will be reflected automatically via a docker volume mount, just as
they would be when running rails directly.

The [Makefile](https://github.com/department-of-veterans-affairs/vets-api/blob/master/Makefile) has shortcuts for many common development tasks. You can still run manual [docker-compose commands](https://docs.docker.com/compose/),
but the following tasks have been aliased to speed development:

## Running tests

- `make spec` - Run the entire test suite via the docker image (alias for `rspec spec`). Test coverage statistics are in `coverage/index.html`.
- `make guard` - Run the guard test server that reruns your tests after files are saved. Useful for TDD!

## Running tests in parallel

- `make spec_parallel_setup` - This sets up the parallel tests databases. First the existing test database is dropped and reset, then the rest of the test databases are cloned off the standard one
- `make spec_parallel` - Run the entire test suite in parallel. A spec folder path can optionally be given as an argument to run just the spec folder in parallel

### Running pending tests

Pending or skipped tests are ignored by default, to run the test suite _with_ pending tests in the output, simply add the PENDING=true environment variable to the test command

`PENDING=true make spec_parallel`

### Running linters

- `make lint` - Run the full suite of linters on the codebase.
- `make security` - Run the suite of security scanners on the codebase.
- `make ci` - Run all build steps performed in CI.

### Running a rails interactive console

- `make console` - Is an alias for `rails console`, which runs an IRB like REPL in which all of the API's classes and
  environmental variables have been loaded.

### Running a bash shell

To emulate a local install's workflow where you can run `rspec`, `rake`, or `rails` commands
directly within the vets-api docker instance you can use the `make bash` command.

```bash
$ make bash
Creating network "vetsapi_default" with the default driver
Creating vetsapi_postgres_1 ... done
Creating vetsapi_redis_1    ... done
# then run any command as you would locally e.g.
root@63aa89d76c17:/src/vets-api# rspec spec/requests/user_request_spec.rb:26
```

### Troubleshooting

As a general technique, if you're running `vets-api` in Docker and run into a problem, doing a `make rebuild` is a good first step to fix configuration, gem, and other various code problems.

#### `make up` failing

Run `make build` and then try `make up` again.

#### `make up` fails with a message about missing gems

```bash
Could not find %SOME_GEM_v0.0.1% in any of the sources
Run `bundle install` to install missing gems.
```

There is no need to run `bundle install` on your system to resolve this.
A rebuild of the `vets_api` image will update the gems. The `vets_api` docker image
installs gems when the image is built, rather than mounting them into a container when
it is run. This means that any time gems are updated in the Gemfile or Gemfile.lock,
it may be necessary to rebuild the `vets_api` image using the
following command:

- `make down` - Stops all docker services.

- `make rebuild` - Rebuild the `vets_api` image.

- `make docker-clean` - Removes all docker images and volumes associated with vets-api.
