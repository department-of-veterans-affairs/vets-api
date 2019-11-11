$stdout.sync = true
export VETS_API_USER_ID  := $(shell id -u)

COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports vets-api bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) --login -c
SPEC_PATH    := spec/

.PHONY: default
default: ci

.PHONY: ci
ci:
	@$(BASH_TEST) "bin/rails db:setup db:migrate ci"

.PHONY: ci-down
ci-down:
	$(COMPOSE_TEST) down

.PHONY: bash
bash:
	@$(COMPOSE_DEV) $(BASH)

.PHONY: ci-build
ci-build:
	$(COMPOSE_TEST) build

.PHONY: ci-db
ci-db:
	@$(BASH_TEST) "bin/rails db:setup db:migrate"	

.PHONY: ci-lint
ci-lint:
	@$(BASH_TEST) "bin/rails lint"

.PHONY: ci-security
ci-security:
	@$(BASH_TEST) "bin/rails security"

.PHONY: ci-spec
ci-spec:
	@$(BASH_TEST) "bin/rails spec:with_codeclimate_coverage"

.PHONY: console
console:
	@$(BASH_DEV) "bundle exec rails c"

.PHONY: danger
danger:
	@$(BASH_TEST) "bundle exec danger --verbose"

.PHONY: db
db:
	@$(BASH_DEV) "bin/rails db:setup db:migrate"

.PHONY: down
down:
	@$(COMPOSE_DEV) down

.PHONY: guard
guard:
	@$(BASH_DEV) "bundle exec guard"

.PHONY: lint
lint:
	@$(BASH_DEV) "bin/rails lint"

.PHONY: migrate
migrate:
	@$(BASH_DEV) "bin/rails db:migrate"

.PHONY: rebuild
rebuild: down
	@$(COMPOSE_DEV) build

.PHONY: security
security:
	@$(BASH_DEV) "bin/rails security"

.PHONY: server
server:
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && bundle exec rails server"

.PHONY: spec
spec:
	@$(BASH_DEV) "bin/rspec ${SPEC_PATH}"

.PHONY: up
up: db
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && foreman start -m all=1,clamd=0,freshclam=0"
