## Running the app Natively

### EKS

Prior to EKS, ClamAV (the virus scanner) was deployed in the same process as Vets API. With EKS, ClamAV has been extracted out into it’s own service. Locally you can see the docker-compose.yml config for clamav.

**TODO**: Running clamav natively, as we did in Vets API master still needs to be configured. For the time being, **please run via docker**:

Please set the [clamav intitalizer](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/config/initializers/clamav.rb) initializers/clamav.rb file to the following:

```
# ## If running hybrid
if Rails.env.development?
   ENV["CLAMD_TCP_HOST"] = "0.0.0.0"
   ENV["CLAMD_TCP_PORT"] = "33100"
 end
```

### Options
#### Option 1: Run ONLY clamav via Docker

You can either run:
`docker-compose -f docker-compose-clamav.yml up` - this will run ONLY clamav via docker

After that, follow the native instructions and run `foreman start -m all=1`

#### Option 2: [See hybrid setup](https://github.com/department-of-veterans-affairs/vets-api/blob/k8s/docs/setup/hybrid.md)

### Running tests

- `bundle exec rake spec` - Run the entire test suite  ( for `rspec spec`). Test coverage statistics are in `coverage/index.html`.
- `make guard` - Run the guard test server that reruns your tests after files are saved. Useful for TDD!

### Running tests in parallel
- NOTE: Running specs in parallel requires that your development database exists, and is up to date. If necessary, you may need to run `bundle exec rake db:create` and `bundle exec rake db:migrate` before the following steps.
- `RAILS_ENV=test bundle exec rake parallel:setup` - This prepares all of the test databases. It will create a test database for each processor on your computer.
- `RAILS_ENV=test NOCOVERAGE=true bundle exec parallel_rspec spec modules` - This runs the entire test suite. Optionally, a folder path can be given as a parameter. Each file is assigned a processor, so it probably doesn't make sense to pass an individual file to run it in parallel. It is currently suggested to forgo the coverage testing by adding `NOCOVERAGE=true` flag (currently the coverage check will fail, even if the test suite passes). If you would like to check coverage for the test run, remove that flag.

### Running linters

- `rake lint` - Run the full suite of linters on the codebase and autocorrect.
- `rake security` - Run the suite of security scanners on the codebase.
- `rake ci` - Run all build steps performed in CI.

### Running a rails interactive console

- `rails console` -  runs an IRB like REPL in which all of the API's classes and environmental variables have been loaded.

### Running with ClamAV

#### Run with ClamAV containers (recommended)

1. In `settings.local.yml` turn mocking off:
```
clamav:
  mock: false
  host: '0.0.0.0'
  port: '33100'
```

1. In another terminal window, navigate to the project directory and run
```
docker-compose -f docker-compose-clamav.yml up
```

1. In the original terminal run the following command
```
foreman start -m all=1,clamd=0,freshclam=0
```

This overrides any configurations that utilize the daemon socket

#### Run with ClamAV daemon

1. In `settings.local.yml` turn mocking off and make sure the host and port are removed:
```
clamav:
  mock: false
```

1. Uncomment socket env var in `config/initializers/clamav.rb`

```
ENV['CLAMD_UNIX_SOCKET'] = '/usr/local/etc/clamav/clamd.sock'
```

*Note you will need to comment this line out before pushing to GitHub*

1. In terminal run the following command
```
foreman start -m all=1
```