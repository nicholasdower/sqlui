ENV ?= development
RUN = ./scripts/docker-run
IMAGE = nicholasdower/sqlui
RUN_IMAGE = $(RUN) $(IMAGE)

RERUN = ./scripts/rerun bin app sql client development_config.yml -not -path client/resources/sqlui.js -type f

.install-from-docker: Gemfile Gemfile.lock .release-version sqlui.gemspec
	npm install
	bundle config set --local path vendor/bundle-docker
	bundle install
	@touch .install-from-docker

.PHONY: install
install:
	@$(RUN_IMAGE) make .install-from-docker

.PHONY: bundle-update
bundle-update:
	$(RUN_IMAGE) /bin/bash -c 'bundle config set --local path vendor/bundle-docker && bundle update'

.PHONY: npm-update
npm-update:
	$(RUN_IMAGE) npm update

.PHONY: update
update: bundle-update npm-update

.PHONY: bundle-outdated
bundle-outdated:
	$(RUN_IMAGE) bundle outdated

.PHONY: upgrade
upgrade:
	$(RUN_IMAGE) npx npm-check-updates --upgrade
	$(RUN_IMAGE) npm update
	$(RUN_IMAGE) bundle outdated

.PHONY: bash
bash:
	$(RUN_IMAGE) bash

.PHONY: build
build: install
	$(RUN_IMAGE) ./scripts/build

.PHONY: build-from-docker
build-from-docker: .install-from-docker
	./scripts/build

.PHONY: lint
lint:
	$(RUN_IMAGE) bundle exec rubocop
	$(RUN_IMAGE) npx eslint client/*.js

.PHONY: lint-fix
lint-fix:
	$(RUN_IMAGE) bundle exec rubocop -A
	$(RUN_IMAGE) npx eslint client/*.js --fix

.PHONY: build-docker-image
build-docker-image:
	docker build --tag $(IMAGE) .

.PHONY: push-docker-image
push-docker-image:
	docker push $(IMAGE)

.PHONY: clean
clean: kill
	rm -rf node_modules
	rm -rf client/resources/sqlui.js
	rm -rf vendor
	rm -rf .bundle*
	rm -rf *.gem
	rm -rf .install*
	rm -rf logs/*

.PHONY: db-logs
db-logs:
	rm -rf logs/mysql-*.log
	mkdir -p logs
	touch logs/mysql-error.log
	touch logs/mysql-general.log
	chmod 666 logs/mysql-*.log

.PHONY: start-db
start-db: db-logs
	docker compose up sqlui_db

.PHONY: start-db-detached
start-db-detached: db-logs
	./scripts/create-docker-network
	./scripts/docker-compose-up-detach sqlui_db
	./scripts/await-healthy-container sqlui_db

.PHONY: seed-db
seed-db:
	docker exec --interactive sqlui_db mysql --user=root --password=root < sql/init.sql

.PHONY: mysql
mysql:
	docker exec --interactive --tty sqlui_db mysql --user=root --password=root $(if $(ARGS),$(ARGS),)

.PHONY: docker-run
docker-run:
	@$(RUN_IMAGE) $(CMD)

.PHONY: start
start: build db-logs
	./scripts/docker-compose-up-detach sqlui_db
	docker compose up sqlui_server

.PHONY: start-detached
start-detached: install db-logs
	./scripts/docker-compose-up-detach sqlui_db
	./scripts/docker-compose-up-detach sqlui_server
	./scripts/await-healthy-container sqlui_server

.PHONY: build-and-start-server-from-docker
build-and-start-server-from-docker: build-from-docker
	./scripts/run-in-env $(ENV) -- bundle exec ruby ./bin/sqlui development_config.yml

.PHONY: start-server-from-docker
start-server-from-docker:
	$(RERUN) -- make build-and-start-server-from-docker

.PHONY: start-selenium
start-selenium:
	docker compose up sqlui_hub sqlui_node-chrome

.PHONY: start-selenium-detached
start-selenium-detached:
	./scripts/docker-compose-up-detach sqlui_hub
	./scripts/docker-compose-up-detach sqlui_node-chrome

.PHONY: unit-test
unit-test: build
	$(RUN) --publish 9090:9090 --name sqlui_test $(IMAGE) ./scripts/run-in-env test -- bundle exec rspec $(if $(ARGS),$(ARGS),spec/app)

.PHONY: watch-unit-test
watch-unit-test:
	$(RERUN) --dir spec/app make uni-test $(if $(ARGS),$(ARGS),)

.PHONY: test
test: build start-db-detached start-selenium-detached
	$(RUN) --publish 9090:9090 --name sqlui_test $(IMAGE) ./scripts/run-in-env test -- bundle exec rspec $(if $(ARGS),$(ARGS),)

.PHONY: watch-test
watch-test:
	$(RERUN) --dir spec make test $(if $(ARGS),$(ARGS),)

.PHONY: stop
stop:
	docker compose down
	@docker network rm sqlui 2> /dev/null || true

.PHONY: kill
kill:
	@docker kill sqlui_server 2> /dev/null || true
	@docker kill sqlui_db 2> /dev/null || true
	@docker kill sqlui_node_chrome 2> /dev/null || true
	@docker kill sqlui_hub 2> /dev/null || true
	@docker kill sqlui_test 2> /dev/null || true
	@docker compose down 2> /dev/null || true
	@docker network rm sqlui 2> /dev/null || true

.PHONY: remvove-containers
remove-containers:
	docker ps --format='{{.ID}}' | while read id; do docker kill "$$id"; done
	docker system prune -f
	docker volume ls -q | while read volume; do docker volume rm -f "$$volume"; done

.PHONY: remove-images
remove-images:
	docker images --format '{{ .Repository }}:{{ .Tag }}' | while read image; do docker rmi "$$image"; done

include Makefile.local
