# Binstubs Overview

The primary objective of these binstubs is to standardize core development commands, such as setup, testing, or linting. Most binstubs come with a `--help` option that outputs the manual for that binstub.

**Run `bin/setup` before running other binstubs**

_for more information about running vets-api_: [Running with Binstubs](running_binstubs.md)

## Setup

```
bin/setup
```

- Replaces the existing manual setup setups by combining most of them into one command with minimal prompts (Currently only supports Mac OSX)
- Some setup steps must be done manually such as Postgres & PostGIS for native
- `bin/setup` for native, docker, and hybrid developer setup
- Setups include `native`,`docker`,`hybrid`, or `base`

_for more information about setup_: [Setup with Binstubs](setup_with_binstubs.md)

## Test

```
bin/test
```

- Replace existing testing command(s)
- Options include --ci, --parallel, --coverage, --log
- Input folders/files can be include like with rspec

*Note*: `pry` is not supported. Consider `pry` alternative: [debugger](https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem)

*Note*: Tests run in parallel can impact each other and fail. See the steps below to debug flaky specs seen in CI.

## Flaky Spec Bisect

```
bin/flaky-spec-bisect <github-actions-url-or-run-id>
```

Shows how to reproduce flaky specs locally by downloading CI artifacts and running `rspec --bisect`. Manual instructions are here: https://depo-platform-documentation.scrollhelp.site/developer-docs/handling-flaky-unit-tests. Once the bisect is complete, it will give you a “minimal reproduction command.” You can reproduce the failure locally by running `bundle exec rspec <minimal reproduction command>`.

- Accepts a GitHub Actions URL (paste in the Summary page URL) or run ID from a failed test run
- Runs `bundle install` automatically if needed
- Run `--help` (or `-h`) to see options. Options include:
    - `--group`, `-g` (target a specific group)
    - `--dry-run`, `-n` (preview commands)
    - `--skip-verify` (skip the reproduction check before bisecting)
    - `--verbose`, `-v` (for extra console output)

**Prerequisites:** GitHub CLI (`gh`) must be installed and authenticated

**Examples:**
```bash
# Basic usage with GitHub Actions URL
bin/flaky-spec-bisect https://github.com/department-of-veterans-affairs/vets-api/actions/runs/12345678

# Dry run to see the commands without executing
bin/flaky-spec-bisect --dry-run <url>

# Target a specific group if multiple failed
bin/flaky-spec-bisect --group "Group 3" <url>
```

## Lint

```
bin/lint
```

- Combines linting, security checks, and CODEOWNERS check found in the CI
- Uses rubocop, brakeman, and bundle-audit
- Options include `--dry`,`--only-rubocop`,`--only-brakeman`
- Inputs can include files and folder
- Autocorrecting in rubocop is on by default, but `--dry` will override autocorrect option

## Docker

```
bin/docker
```

- Provides common Docker-related commands for managing Docker containers and images
- Commands include but not limited to:
  - **clean:** Prunes unused Docker objects and rebuilds the images.
  - **rebuild:** Stops running containers and builds the images without cache.
  - **build:** Stops running containers and builds the images with cache.
  - **db:** Prepares the database for development and test environments.

## Others

- `bin/help` - Display `vets-api` related binstub manual
- `bin/info` - Display version related information
- `bin/dev`  - Starts the server (or containers)

The output from `bin/info` may be use for support requests

## FAQ

### Setup Preference

Your setup preference is stored in the root file `.developer-setup`. Test, lint, and dev binstubs rely on the stored preference to determine how to run the tests. If you plan on testing and linting with vets-api, native is strongly recommended.

### Switch Setups

Let's say you want to switch from native setup to docker setup. All you need to do is run the setup binstub with the desired option, in this case: `bin/setup --docker`.

### Running old commands

If you need to run a docker command like `docker system prune` or you want to run `rubocop -A`, you are still able to use any other command you would have used before.

### Reporting Issues

Please contact support with any issues that can't be resolved using:

- [Troubleshooting Common Docker Issues](running_binstubs.md#troubleshooting-common-docker-issues)
- [Troubleshooting Common Setup Issues](setup_with_binstubs.md#troubleshooting-common-setup-issues)
