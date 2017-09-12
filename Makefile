COMPOSE_DEV		:= docker-compose
COMPOSE_TEST		:= docker-compose -f docker-compose.test.yml
BASH_DEV		:= $(COMPOSE_DEV) run --rm vets-api bash --login -c
BASH_TEST		:= $(COMPOSE_TEST) run --rm vets-api bash --login -c

.PHONY: default
default: ci

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
guard: db
	@$(BASH_DEV) "bundle exec guard"

.PHONY: lint
lint: db
	@$(BASH_DEV) "bundle exec rake lint"

.PHONY: security
security: db
	@$(BASH_DEV) "bundle exec rake security"

.PHONY: spec
spec:
	@$(BASH_TEST) "bundle exec rake spec"

.PHONY: up
up: db
	@$(COMPOSE_DEV) up

.PHONY: clean
clean:
	rm -rf data
	$(COMPOSE_TEST) run vets-api rm -r coverage log tmp
	$(COMPOSE_TEST) down
