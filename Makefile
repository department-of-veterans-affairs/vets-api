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

ifdef PACT_URI
	PACT := "RAILS_ENV=test bundle exec rake pact:verify:at[$(PACT_URI)]"
else
    PACT := "RAILS_ENV=test bundle exec rake pact:verify"
endif



COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports vets-api bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) --login -c
SPEC_PATH    := spec/
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

.PHONY: pact
pact:
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(PACT)
else
	@$(BASH_TEST) $(PACT)
endif

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
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) "bin/rspec ${SPEC_PATH}"
else
	@$(BASH_TEST) "bin/rails spec:with_codeclimate_coverage"
endif

.PHONY: up
up: db  ## Starts the server and associated services with docker-compose, use `clam=1 make up` to run ClamAV
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && foreman start -m ${FOREMAN_ARG}"
