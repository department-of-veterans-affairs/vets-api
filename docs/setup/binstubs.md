# Binstubs

The primary objective of these binstubs is to standardize core development commands, such as setup, testing, or linting. Most binstubs come with a `--help` option that outputs the manual for that binstub. 

**Run `bin/setup` before running other binstubs**

## Setup

```
bin/setup 
```

- Replaces the existing manual setup setups by combining most of them into one command with minimal prompts (Currently only supports Mac OSX)
- Some setup steps must be done manually such as Postgres & PostGIS for native
- `bin/setup` for native, docker, and hybrid developer setup
- Setups include `native`,`docker`,`hybrid`, or `base`
- Setup preference from setup is stored in .developer-setup

_Note:_ If using the native or hybrid setup you will need to install Ruby before running `bin/setup`

_Note:_ The native setup is the preferred setup for working on vets-api. Docker is the preferred setup for using vets-api while working on vets-website

## Test

```
bin/test 
```

- Replace existing testing command(s)
- Options include --ci, --no-parallel, --coverage, --log
- Input folders/files can be include like with rspec 
- Uses the .developer-setup preference for the testing environment

## Lint

```
bin/lint 
```

- Combines linting and security checks found in the CI
- Uses rubocop, brakeman, and bundle-audit
- Options include `--dry`,`--only-rubocop`,`--only-brakeman`
- Inputs can include files and folder 
- Autocorrecting in rubocop is on by default, but `--dry` will override autocorrect option

## Others

- `bin/help` - Display `vets-api` related binstub manual
- `bin/info` - Display version related information
- `bin/dev`  - Starts the server (or containers)

## FAQ

### Switch Setups

Let's say you want to switch from native setup to docker setup. All you need to do is run the setup binstub with the desired option, in this case: `bin/setup --docker`. 

### Running old commands

If you need to run a docker command like `docker system prune` or you want to run `rubocop -A`, you are still able to use any other command you would have used before. 

## Common Issues

### Database Connection

If running natively and you see this error: 

 `PG::ConnectionBad: connection to server on socket "/tmp/.s.PGSQL.5432" failed: No such file or directory`

Resolution: You may need to start the Postgres App

### Setup Failures 

If issues occur during setup you may need to follow the instructions provided in the docs: [native](native.md), [hybrid](hybrid.md), or [docker](docker.md)

#### Flipper Issues

Error: `You likely need to run 'rails g flipper:active_record' and/or 'rails db:migrate'.`

Resolution: You may see this error on your first run because the table doesn't yet exist and the flipper gem is throwing the warning. Simply run the setup command again and the error will go away

### .developer-setup Issues

#### Missing File 

Error: `No such file or directory @ rb_sysopen - .developer-setup (Errno::ENOENT)`

Resolution: You must run `bin/setup` before running the other binstubs

#### Invalid Setup Preference
Error: `Invalid option for .developer-setup`

Resolution: In the .developer-setup ensure the value is either `native`, `hybrid`, or `docker`

### I'm using Linux or Windows

Only MacOSX is supported as of 5/16/24. More OS support is not yet planned. 
