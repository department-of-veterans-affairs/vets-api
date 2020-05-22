$stdout.sync = true
export VETS_API_USER_ID  := $(shell id -u)

ifdef env
    ENV_ARG  := $(env)
else
    ENV_ARG	 := dev
endif

COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports vets-api bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) --login -c
SPEC_PATH    := spec/
DB		     := "bin/rails db:setup db:migrate"
LINT    	 := "bin/rails lint"
DOWN         := down
SECURITY     := "bin/rails security"

.PHONY: default
default: ci

.PHONY: ci
ci:
	@$(BASH_TEST) "bin/rails db:setup db:migrate ci"

.PHONY: bash
bash:
	@$(COMPOSE_DEV) $(BASH)

.PHONY: build
build:
ifeq ($(ENV_ARG), dev)
	$(COMPOSE_DEV) build
else
	$(COMPOSE_TEST) build
endif


.PHONY: db
db:
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(DB)
else
	@$(BASH_TEST) $(DB)
endif


.PHONY: lint
lint:
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(LINT)
else
	@$(BASH_TEST) $(LINT)
endif

.PHONY: console
console:
	@$(BASH_DEV) "bundle exec rails c"

.PHONY: danger
danger:
	@$(BASH_TEST) "bundle exec danger --verbose"

.PHONY: docker-clean
docker-clean:
	@$(COMPOSE_DEV) down --rmi all --volumes

.PHONY: down
down:
ifeq ($(ENV_ARG), dev)
	@$(COMPOSE_DEV) $(DOWN)
else
	@$(COMPOSE_TEST) $(DOWN)
endif

.PHONY: guard
guard:
	@$(BASH_DEV) "bundle exec guard"

.PHONY: migrate
migrate:
	@$(BASH_DEV) "bin/rails db:migrate"

.PHONY: rebuild
rebuild: down
	@$(COMPOSE_DEV) build

.PHONY: security
security:
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) $(SECURITY)
else
	@$(BASH_TEST) $(SECURITY)
endif

.PHONY: server
server:
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && bundle exec rails server"

.PHONY: spec
spec:
ifeq ($(ENV_ARG), dev)
	@$(BASH_DEV) "bin/rspec ${SPEC_PATH}"
else
	@$(BASH_TEST) "bin/rails spec:with_codeclimate_coverage"
endif

.PHONY: up
up: db
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && foreman start -m all=1,clamd=0,freshclam=0"
