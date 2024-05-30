# Beta-testing Binstubs

The purpose of these vets-api binstubs is to create a consistent developer environment between native, hybrid, and docker setups. 

## Installation

The binstubs do not require any special installation. It should work out of the box. 

## Compatibility 

bin/setup is only officially supported for Mac OSX. For those using Linux or Windows, use the `--base` option for a basic setup. Although not officially supported, the docker setup may work on Linux and Windows. 

All other binstubs can be used by Mac, Linux, or Windows. 

## List of binstubs

- bin/help
- bin/info
- bin/lint
- bin/setup
- bin/test
- bin/deps

### bin/setup

- Creates the developer setup for native, hybrid, or docker 
- This setups local settings, database, parallel_tests, and binary dependencies such as pdftk 

Run `bin/setup --help` for usage info and example 

### bin/test

- Replace existing testing commands such as `rspec`, `parallel_rspec`, `make spec_parallel`
- This command does not include parallel database setup
- `--ci` requires docker to be install and setup  

Run `bin/test --help` for usage info and example 

### bin/lint

- Replaces `make lint` 
- Runs rubocop, brakeman, and bundle-audit
- Autocorrecting in rubocop is on by default, but `--dry` will override autocorrect option

Run `bin/lint --help` for usage info and example 

### others

- `bin/help`: Display `vets-api` related binstubs
- `bin/info`: Display version related information

## Reporting a Bug or Feature Suggest 

Create an issue in va.gov-team repo using the title 

- `binstubs bug ...`
- `binstubs feature ...`

Please also assign `stevenjcumming` with the label `platform-reliability-team`


## Getting Started

After checking out the `sjc-binstubs` branch, run `bin/setup` with your desired setup.

```bash
# Example

bin/setup --native
```

This will create a new file `.developer-setup` to store your setup preference. You can switch this at any time by rerun the setup binstub. Some setup steps will be skipped if already completed. 

After setup, you can test or lint with the corresponding binstub. `bin/test` may take longer to load and start testing because bootsnap is disable, as it is on the CI. 

## Troubleshooting Tips

(TBD)
