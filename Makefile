INTERACTIVE := $(shell [ -t 0 ] && echo --tty --interactive)
RUN = docker run --rm $(INTERACTIVE) --network sqlui_default --volume `pwd`:/sqlui --workdir /sqlui
IMAGE = nicholasdower/sqlui
RUN_IMAGE = $(RUN) $(IMAGE)

RERUN = ./scripts/rerun --dir bin --dir app --dir sql --file client/sqlui.js --file client/resources/sqlui.css --file client/resources/sqlui.html --file development_config.yml

.PHONY: create-network
create-network:
	@docker network inspect sqlui_default >/dev/null 2>&1 || docker network create --driver bridge sqlui_default > /dev/null

.install-from-docker:
	npm install
	bundle config set --local path vendor/bundle-docker
	bundle install
	@touch .install
	@touch .install-from-docker

.install: Gemfile Gemfile.lock
	@make create-network
	$(RUN_IMAGE) make .install-from-docker

.PHONY: install
install: .install

.PHONY: update
update: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm update && bundle config set --local path vendor/bundle-docker && bundle update'

.PHONY: tools-check
tools-check:
	@./scripts/tools-check

.PHONY: update-local
update-local: tools-check
	npm update
	bundle config set --local path vendor/bundle-local
	bundle update

.install-local: Gemfile Gemfile.lock
	@make tools-check
	npm install
	bundle config set --local path vendor/bundle-local
	bundle install
	@touch .install-local

.PHONY: install-local
install-local: .install-local

.PHONY: bash
bash: create-network
	$(RUN_IMAGE) bash

.PHONY: build
build: install create-network
	$(RUN_IMAGE) ./scripts/build

.PHONY: build-from-docker
build-from-docker: .install-from-docker
	./scripts/build

.PHONY: build-local
build-local: tools-check install-local
	./scripts/build

.PHONY: lint
lint: create-network
	$(RUN_IMAGE) bundle exec rubocop
	$(RUN_IMAGE) npx eslint client/*.js

.PHONY: lint-local
lint-local: tools-check
	bundle exec rubocop
	npx eslint client/*.js

.PHONY: lint-fix
lint-fix: create-network
	$(RUN_IMAGE) bundle exec rubocop -A
	$(RUN_IMAGE) npx eslint client/*.js --fix

.PHONY: lint-fix-local
lint-fix-local: tools-check
	bundle exec rubocop -A
	npx eslint client/*.js --fix

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

.PHONY: start-db
start-db:
	docker compose up sqlui_db

.PHONY: start-db-detached
start-db-detached:
	./scripts/docker-compose-up-detach sqlui_db

.PHONY: stop-db
stop-db:
	docker compose down sqlui_db

.PHONY: seed-db
seed-db:
	docker exec --interactive sqlui_db mysql --host=db --protocol=tcp --user=root --password=root < sql/init.sql

.PHONY: seed-db-local
seed-db-local:
	mysql --protocol=tcp --user=root --password=root < sql/init.sql

.PHONY: mysql
mysql:
	docker exec --interactive --tty sqlui_db mysql --user=root --password=root $(if $(QUERY),--execute "$(QUERY)",)

.PHONY: mysql-local
mysql-local:
	mysql --user=root --password=root $(if $(QUERY),--execute "$(QUERY)",)

.PHONY: docker-run
docker-run: create-network
	@$(RUN_IMAGE) $(CMD)

.PHONY: start
start: build
	./scripts/docker-compose-up-detach sqlui_db
	docker compose up sqlui_server

.PHONY: start-detached
start-detached: install
	./scripts/docker-compose-up-detach sqlui_db
	./scripts/docker-compose-up-detach sqlui_server
	./scripts/await-healthy-container sqlui_server

.PHONY: build-and-start-server-from-docker
build-and-start-server-from-docker: build-from-docker
	bundle exec ruby ./bin/sqlui development_config.yml

.PHONY: start-server-from-docker
start-server-from-docker:
	$(RERUN) -- make build-and-start-server-from-docker

.PHONY: build-and-start-server-local
build-and-start-server-local: build-local
	bundle exec ruby ./bin/sqlui development_config.yml

.PHONY: start-local
start-local: start-db-detached
	./scripts/await-healthy-container sqlui_db
	$(RERUN) -- make build-and-start-server-local

.PHONY: start-selenium
start-selenium:
	docker compose up sqlui_hub sqlui_node-chrome

.PHONY: start-selenium-detached
start-selenium-detached:
	./scripts/docker-compose-up-detach sqlui_hub
	./scripts/docker-compose-up-detach sqlui_node-chrome

.PHONY: unit-test
unit-test: build
	$(RUN) --env DB_HOST=sqlui_db --publish 9090:9090 --name sqlui_test $(IMAGE) bundle exec rspec $(if $(ARGS),$(ARGS),spec/app)

.PHONY: watch-unit-test
watch-unit-test:
	$(RERUN) --dir spec/app make uni-test $(if $(ARGS),$(ARGS),)

.PHONY: test
test: build start-db-detached start-selenium-detached
	./scripts/await-healthy-container sqlui_db
	$(RUN) --env DB_HOST=sqlui_db --publish 9090:9090 --name sqlui_test $(IMAGE) bundle exec rspec $(if $(ARGS),$(ARGS),)

.PHONY: watch-test
watch-test:
	$(RERUN) --dir spec make test $(if $(ARGS),$(ARGS),)

.PHONY: unit-test-local
unit-test-local: build-local
	LOCAL=true bundle exec rspec $(if $(ARGS),$(ARGS),spec/app)

.PHONY: watch-unit-test-local
watch-unit-test-local:
	$(RERUN) --dir spec/app make unit-test-local $(if $(ARGS),ARGS=$(ARGS),)

.PHONY: test-local
test-local: build-local start-db-detached start-selenium-detached
	./scripts/await-healthy-container sqlui_db
	LOCAL=true bundle exec rspec $(if $(ARGS),$(ARGS),)

.PHONY: watch-test-local
watch-test-local:
	$(RERUN) --dir spec make test-local $(if $(ARGS),ARGS=$(ARGS),)

.PHONY: stop
stop:
	docker compose down
	@docker network rm sqlui_default 2> /dev/null || true

.PHONY: kill
kill:
	@docker kill sqlui_server 2> /dev/null || true
	@docker kill sqlui_db 2> /dev/null || true
	@docker kill sqlui_node_chrome 2> /dev/null || true
	@docker kill sqlui_hub 2> /dev/null || true
	@docker kill sqlui_test 2> /dev/null || true
	@docker compose down 2> /dev/null || true
	@docker network rm sqlui_default 2> /dev/null || true
