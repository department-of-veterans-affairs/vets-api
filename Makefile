$stdout.sync = true
COMPOSE_DEV  := docker-compose
COMPOSE_TEST := docker-compose -f docker-compose.test.yml
BASH         := run --rm --service-ports vets-api bash
BASH_DEV     := $(COMPOSE_DEV) $(BASH) -c
BASH_TEST    := $(COMPOSE_TEST) $(BASH) --login -c
SPEC_PATH    := spec/

# docker-compose -f docker-compose.test.yml run --rm --service-ports vets-api bash --login -c bin/rails db:setup db:migrate ci

.PHONY: default
default: ci
.PHONY: bash
bash:
	@$(COMPOSE_DEV) $(BASH)

.PHONY: ci
ci:
	@$(BASH_TEST) "bin/rails db:setup db:migrate ci"

.PHONY: clean
clean:
	rm -r data || true
	$(COMPOSE_TEST) run vets-api rm -r coverage log tmp .git || true
	$(COMPOSE_TEST) down

.PHONY: console
console:
	@$(BASH_DEV) "bundle exec rails c"

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
	@$(BASH_TEST) "bin/rails db:migrate"

.PHONY: test_db
test_db:
	@$(BASH_TEST) "bin/rails db:setup db:migrate"	

.PHONY: lint_ci
lint_ci:
	@$(BASH_TEST) "bin/rails lint"

.PHONY: security_ci
security_ci:
	@$(BASH_TEST) "bin/rails security"

.PHONY: danger
danger:
	@$(BASH_TEST) "bundle exec danger --verbose"

.PHONY: spec_ci
spec_ci:
	@$(BASH_TEST) "bin/rails spec:with_codeclimate_coverage"

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
	@$(BASH_TEST) "bin/rspec ${SPEC_PATH}"

.PHONY: up
up: db
	@$(BASH_DEV) "rm -f tmp/pids/server.pid && foreman start"

