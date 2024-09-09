# Running vets-api with Binstubs

This guide provides instructions for using the binstubs provided in this repository to run the API and manage the Docker containers/environment.

## Prerequisites

Before using theses binstubs, ensure that you have completed `bin/setup` and have Ruby and/or Docker running on your machine. 

## Using bin/dev

```sh
bin/dev
```

The `bin/dev` binstub is used to set up and start the development environment based on the configuration specified in the `.developer-setup` file. It supports the following configurations:

- **native:** Starts the web and job processes.
- **docker:** Starts the docker process (docker-compose up)
- **hybrid:** Starts the web, job, and additional services (deps: clamav, postgres, redis).

### Usage

This command will automatically determine the setup based on the configuration in .developer-setup.

For more information, you can use the help command: `bin/dev help`

## Using bin/docker

The `bin/docker` binstub provides common Docker-related commands for managing Docker containers and images.

### Commands

- **clean:** Prunes unused Docker objects and rebuilds the images.
- **rebuild:** Stops running containers and builds the images without cache.
- **build:** Stops running containers and builds the images with cache.
- **stop:** Stops all running Docker containers.
- **startd:** Starts Docker containers in the background.
- **console:** Starts the Rails console.
- **bundle:** Installs Ruby gems.
- **db:** Prepares the database for development and test environments.
- **ci:** Prepares the Docker environment to run `bin/test --ci`.

### Usage

```sh
bin/docker COMMAND
```

Replace COMMAND with one of the commands listed above.

For more information about each command, you can use the help command: `bin/docker help`

This will display a help message with descriptions of each command and examples of usage.

### Troubleshooting Common Docker Issues

#### bundler

You may see an error like:

`Couldn't find A, B, C in locally installed gems...`

You can use `bin/docker bundle` to resolve these issues. 

#### database

`We couldn't find your database: vets_api_development`

If you haven't setup your database, you can run `bin/docker db` to setup the development, test environment database, and the parallel_test databases. 

#### something else

Some errors may be causes by a bad container or image, for this you can run the following commands to reset your docker environment:

```
1. bin/docker clean
2. bin/docker rebuild
3. bin/docker bundle
```

Note this may take a while to run all three commands

## Using bin/test

There are two ways to test vets-api 

- CI test
- non-CI test

The CI test matches the GitHub CI Code Check - Test Specs as close as possible, including testing the full suite in docker. This flag overrides all other flags provided. 

The non-CI test run based on your developer setup preference. This can run in parallel or not, with code coverage or not, and output to a log or not. The default is no parallel, no coverage, and no log. Additionally, bootsnap is disabled by default to more closely match the CI. You can also specify a file or directory to test. 

### Examples
```
# For running a tests with debugger or a small group of specs
# run without parallel

bin/test spec/to/file_spec.rb

# For larger groups of tests without debugging
# run with parallel

bin/test --parallel modules/mobile
```



## Using bin/lint

Before pushing your code changes, you can use `bin/lint` to perform rubocop autocorrect, security checks, and CODEOWNER checks. 

Options includes a dry run (no rubocop autocorrect), only rubocop, only brakeman. You can also specify a directory or file for rubocop. 

`bin/lint lib/forms/client.rb`

For more information about each option, you can use the help command: `bin/lint --help`
