# Running with Binstubs

This guide provides instructions for using the binstubs provided in this repository to run the API and manage the Docker containers/environment.

## Prerequisites

Before using theses binstubs, ensure that you have completed `bin/setup` and have Ruby and/or Docker running on your machine. 

## Using bin/dev

The `bin/dev` binstub is used to set up and start the development environment based on the configuration specified in the `.developer-setup` file. It supports the following configurations:

- **native:** Starts the web and job processes.
- **docker:** Starts the docker process (docker-compose up)
- **hybrid:** Starts the web, job, and additional services (deps: clamav, postgres, redis).

### Usage

```sh
bin/dev
```

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
