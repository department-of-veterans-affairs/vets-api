$stdout.sync = true
export VETS_API_USER_ID  := $(shell id -u)

ifdef env
    ENV_ARG  := $(env)
else
    ENV_ARG	 := dev
endif

ifdef clam
	FOREMAN_ARG := all=1
else
	FOREMAN_ARG := all=1,clamd=0,freshclam=0
endif

COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports web bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) --login -c
SPEC_PATH    := spec/ modules/
DB           := "bin/rails db:setup db:migrate"
LINT         := "bin/rails lint['$(files)']"
DOWN         := down
SECURITY     := "bin/rails security"
.DEFAULT_GOAL := ci


# cribbed from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html and https://news.ycombinator.com/item?id=11195539
help:  ## Prints out documentation for available commands
	@awk -F ':|##' \
		'/^[^\t].+?:.*?##/ {\
			printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
		}' $(MAKEFILE_LIST)

.PHONY: ci
ci:  ## Sets up databases and runs tests for ci
	@$(BASH_TEST) "bin/rails db:setup db:migrate ci"

.PHONY: bash
bash:  ## Starts a bash shell inside the docker container
	@$(COMPOSE_DEV) $(BASH)

.PHONY: build
build:  ## Builds the api
ifeq ($(ENV_ARG), dev)
	$(COMPOSE_DEV) build
else
	$(COMPOSE_TEST) build
endif

.PHONY: db
db:  ## Sets up database and runs migrations
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(DB)
else
	@$(BASH_TEST) $(DB)
endif

.PHONY: lint
lint:  ## runs the linter
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(LINT)
else
	@$(BASH_TEST) $(LINT)
endif

.PHONY: console
console:  ## Starts a rails console
	@$(BASH_DEV) "bundle exec rails c"

.PHONY: danger
danger:  ## Runs the danger static analysis
	@$(BASH_TEST) "bundle exec danger --verbose"

.PHONY: docker-clean
docker-clean:  ## Removes all docker images and volumes associated with vets-api
	@$(COMPOSE_DEV) down --rmi all --volumes

.PHONY: down
down:  ## Stops all docker services
ifeq ($(ENV_ARG), dev)
	@$(COMPOSE_DEV) $(DOWN)
else
	@$(COMPOSE_TEST) $(DOWN)
endif

.PHONY: guard
guard:  ## Runs guard
	@$(BASH_DEV) "bundle exec guard"

.PHONY: migrate
migrate:  ## Runs the database migrations
	@$(BASH_DEV) "bin/rails db:migrate"

.PHONY: rebuild
rebuild: down  ## Stops the docker services and builds the api
	@$(COMPOSE_DEV) build

.PHONY: security
security:  ## Runs security scans
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(SECURITY)
else
	@$(BASH_TEST) $(SECURITY)
endif

.PHONY: server
server:  ## Starts the server (natively)
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && bundle exec rails server"

.PHONY: spec
spec:  ## Runs spec tests
	@$(BASH_DEV) "RAILS_ENV=test bin/rspec ${SPEC_PATH}"

.PHONY: spec_parallel_setup
spec_parallel_setup:  ## Setup the parallel test dbs. This resets the current test db, as well as the parallel test dbs
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) "RAILS_ENV=test DISABLE_BOOTSNAP=true bundle exec parallel_test -e 'bundle exec rake db:reset db:migrate'"
else
	@$(COMPOSE_TEST) $(BASH) -c "RAILS_ENV=test DISABLE_BOOTSNAP=true parallel_test -e 'bundle exec rake db:reset db:migrate'"
endif

.PHONY: spec_parallel
spec_parallel:  ## Runs spec tests in parallel
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) "RAILS_ENV=test DISABLE_BOOTSNAP=true NOCOVERAGE=true bundle exec parallel_rspec ${SPEC_PATH}"
else
	@$(COMPOSE_TEST) $(BASH) -c "DISABLE_BOOTSNAP=true bundle exec parallel_rspec ${SPEC_PATH}"
endif

.PHONY: up
up: db  ## Starts the server and associated services with docker-compose
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && bundle exec foreman start -m all=1"

# NATIVE COMMANDS
.PHONY: native-up
native-up:
	bundle install
	foreman start -m all=1

.PHONY: native-lint
native-lint:
	bundle exec rake lint

.PHONY: native-spec
native-spec:
	bundle exec rake spec

.PHONY: native-spec-parallel
native-spec-parallel:
	RAILS_ENV=test NOCOVERAGE=true bundle exec rake parallel:spec

.PHONY: native-spec-parallel-setup
native-spec-parallel-setup:
	RAILS_ENV=test bundle exec rake parallel:setup

.PHONY: bootstrap
bootstrap:  ## Runs bin/bootstrap_docker script
	./bin/bootstrap_docker
