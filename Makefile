COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports vets-api bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) --login -c

.PHONY: default
default: ci

.PHONY: bash
bash:
	@$(COMPOSE_DEV) $(BASH)

.PHONY: ci
ci:
	@$(BASH_TEST) "bundle exec rake db:create && bundle exec rake db:migrate ci"

.PHONY: clean
clean:
	rm -r data || true
	$(COMPOSE_TEST) run vets-api rm -r coverage log tmp || true
	$(COMPOSE_TEST) down

.PHONY: console
console:
	@$(BASH_DEV) "bundle exec rails c"

.PHONY: db
db:
	@$(BASH_DEV) "bundle exec rake db:create && bundle exec db:migrate"

.PHONY: down
down:
	@$(COMPOSE_DEV) down

.PHONY: guard
guard:
	@$(BASH_DEV) "bundle exec guard"

.PHONY: lint
lint:
	@$(BASH_DEV) "bundle exec rake lint"

.PHONY: migrate
migrate:
	@$(BASH_TEST) "bundle exec rake db:migrate"

.PHONY: rebuild
rebuild: down
	@$(COMPOSE_DEV) build

.PHONY: security
security:
	@$(BASH_DEV) "bundle exec rake security"

.PHONY: server
server:
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && bundle exec rails server"

.PHONY: spec
spec:
	@$(BASH_TEST) "bundle exec rake spec"

.PHONY: up
up: db
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && foreman start"
