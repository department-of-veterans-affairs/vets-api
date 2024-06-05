# Setup vets-api with Binstubs

Binstubs allows you to almost completely setup your computer to run `vets-api`

_Caveat:_ Only macOS is supported as of 5/16/24. More OS support is not yet planned. 

## How to Choose

### Native

If you plan on developing for vets-api, the native setup is **strongly** recommended. This can include the need to run tests, linting, etc.

### Docker

If you don't plan developing for vets-api, and you just need it to run, Docker is best option. 

### Hybrid

If you don't feel comfortable or don't want to worry about installing things like Postgres, the Hybrid setup is a good choice. 

## Getting Started

### Prerequisites

#### Ruby 

If running natively or hybrid, you'll need to install the correct ruby version via your ruby version manager of choice. 

#### Postgres

If running the docker or hybrid setup, you don't need to install postgres. `bin/setup` will attempt to install postgres and related extensions, however this is rather tricky and frequently fails. You can install postgres via the [Postgres app](https://postgresapp.com/downloads) (PostgreSQL 15.7 / PostGIS 3.3.6)   

If postgres is already install, make sure it is running and the setup binstub will skip the install. 

#### Docker

If you are running vets-api via docker, running hybrid, OR want to test the full rspec suite like the CI, you'll need to install docker. 

#### Sidekiq License 

Although not required to run vets-api, if you plan to develop for vets-api, you'll need the sidekiq enterprise license, that can be found [here](https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/engineering/sidekiq-enterprise-setup.md) Note: this is a private repo. 

### Clone vets-api

You'll also need to clone vets-api. If you don't have git installed you'll need to install `git` as well: 

`git clone https://github.com/department-of-veterans-affairs/vets-api.git`

### bin/setup

After you have the necessary prerequisites it's time to run the command

`bin/setup <SETUP_CHOICE>`

This will install/setup the base (or common) settings/setup including:
- certificates
- local settings
- mockdata repo

You may also be prompted to input the sidekiq enterprise license if you don't already have it configured. 

After the base setup, the setup will follow the setup preference provided in the command.Many settings are skipped if already configured. The rest of the setup will include bundling gems, creating/migrating the database, and setting up the parallel testing environment. 

#### CI Preparation

If you just use docker for testing the full rspec suite like the CI, you can run the ci command. This will build, bundle the gems, and setup parallel_test databases. 

`bin/docker ci`

## After Setup

You may want to run specific commands for docker or a ruby gems, and you'll be able to run them as with any typical Rails application, like `docker system prune`, `rails generate`, or `rubocop -A`. Binstubs are intended to replace, not remove, some common commands to provide a unified developer experience regardless of the setup. 

## Troubleshooting Common Setup Issues

### Database Connection

If running natively and you see this error: 

 `PG::ConnectionBad: connection to server on socket "/tmp/.s.PGSQL.5432" failed: No such file or directory`

Resolution: You may need to start the Postgres App

### Setup Failures 

If issues occur during setup you may need to follow the instructions provided in the docs: [native](native.md), [hybrid](hybrid.md), or [docker](docker.md)

#### Flipper Issues

Error: `You likely need to run 'rails g flipper:active_record' and/or 'rails db:migrate'.`

Resolution: You may see this error on your first run because the table doesn't yet exist and the flipper gem is throwing the warning. You can ignore this error/warning or simply run the setup command again and the error will go away. 

### .developer-setup Issues

#### Missing File 

Error: `No such file or directory @ rb_sysopen - .developer-setup (Errno::ENOENT)`

Resolution: You must run `bin/setup` before running the other binstubs

#### Invalid Setup Preference
Error: `Invalid option for .developer-setup`

Resolution: In the .developer-setup ensure the value is either `native`, `hybrid`, or `docker`

### I'm using Linux or Windows

Only MacOSX is supported as of 5/16/24. More OS support is not yet planned. 
