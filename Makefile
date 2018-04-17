COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports vets-api bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) -c

.PHONY: default
default: ci

.PHONY: bash
bash:
	@$(COMPOSE_DEV) $(BASH)

.PHONY: ci
ci:
	@$(BASH_TEST) "bundle exec rake db:setup db:migrate ci"

.PHONY: console
console:
	@$(BASH_DEV) "bundle exec rails c"

.PHONY: db
db:
	@$(BASH_DEV) "bundle exec rake db:setup db:migrate"

.PHONY: guard
guard:
	@$(BASH_DEV) "bundle exec guard"

.PHONY: lint
lint:
	@$(BASH_DEV) "bundle exec rake lint"

.PHONY: security
security:
	@$(BASH_DEV) "bundle exec rake security"

.PHONY: spec
spec: db
	@$(BASH_TEST) "bundle exec rake spec"

.PHONY: up
up: db
	@$(BASH_DEV) "foreman start"

.PHONY: rebuild
rebuild:
	@$(COMPOSE_DEV) down
	@$(COMPOSE_DEV) build

.PHONY: clean
clean:
	rm -r data || true
	$(COMPOSE_TEST) run vets-api rm -r coverage log tmp || true
	$(COMPOSE_TEST) down

.PHONY: clean_pids
clean_pids:
	rm -rf ./tmp/pids/*
