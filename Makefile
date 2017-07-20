COMPOSE_DEV		:= docker-compose -f docker-compose.yml -f docker-compose.dev.yml
BASH_DEV		:= $(COMPOSE_DEV) run vets-api bash --login -c

.PHONY: default
default: ci

.PHONY: ci
ci:
	@$(BASH_DEV) "bundle exec rake ci"

.PHONY: guard
guard:
	@$(BASH_DEV) "bundle exec guard"

.PHONY: lint
lint:
	@$(BASH_DEV) "bundle exec rake lint"

.PHONY: run
run:
	@$(COMPOSE_DEV) run vets-api

.PHONY: security
security:
	@$(BASH_DEV) "bundle exec rake security"

.PHONY: test
test:
	@$(BASH_DEV) "bundle exec rake test"

.PHONY: clean
clean:
	rm -r data
	$(COMPOSE_DEV) down
