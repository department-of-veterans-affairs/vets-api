# Vets Api Binstubs 

## Plan

1. Create a list of commands
2. Implement commands (mac, windows, multiple linux distro)
3. Beta testing 
4. Update as needed
5. Rewrite documentation

## List of Commands

- help = list commands and options 
- info = display version related information
- setup = runs either native, docker setup or both
  - would like to make a new file .developer-environment with native, docker, both to store their preference
  - could use this with --hard flag to re-setup everything
- status/diagnosis = identify potential configuration/setup issues acts as a checklist (such as docker, redis, rspec, settings, etc)
- lint = runs the full suite of linters on the codebase.
- test = runs the testing environment
  - could have lots of options --ci, --parallel, --only-failures, etc
- start = start the api
- stop = stop the api 

### Docker specific commands
- build = docker command to rebuild 
- clean = Removes all docker images and volumes associated with vets-api.
- security = Runs security scans 
