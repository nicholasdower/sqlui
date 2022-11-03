.PHONY: *

INTERACTIVE := $(shell [ -t 0 ] && echo --tty --interactive)
RUN = docker run --rm $(INTERACTIVE) --env BUNDLE_APP_CONFIG=/sqlui/.bundle --network sqlui_default --volume `pwd`:/sqlui --workdir /sqlui
IMAGE = nicholasdower/sqlui
RUN_IMAGE = $(RUN) $(IMAGE)

RERUN = ./scripts/rerun --dir bin --dir app --dir sql --file client/sqlui.js --file client/resources/sqlui.css --file client/resources/sqlui.html --file development_config.yml

create-network:
	@docker network inspect sqlui_default >/dev/null 2>&1 || docker network create --driver bridge sqlui_default > /dev/null

install: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm install && bundle config set --local path vendor/bundle && bundle install'

update: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm update && bundle update'

nvm-use:
	@./scripts/nvm-use

update-local: nvm-use
	npm update
	bundle config set --local path vendor/bundle
	bundle update

install-local: nvm-use
	npm install
	bundle config set --local path vendor/bundle
	bundle install

bash: create-network
	$(RUN_IMAGE) bash

build: create-network
	$(RUN_IMAGE) make build-local

build-local: nvm-use
	rm -f client/resources/sqlui.js
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs
	chmod 444 client/resources/sqlui.js

lint: create-network
	$(RUN_IMAGE) bundle exec rubocop
	$(RUN_IMAGE) npx eslint client/*.js

lint-local: nvm-use
	bundle exec rubocop
	npx eslint client/*.js

lint-fix: create-network
	$(RUN_IMAGE) bundle exec rubocop -A
	$(RUN_IMAGE) npx eslint client/*.js --fix

lint-fix-local: nvm-use
	bundle exec rubocop -A
	npx eslint client/*.js --fix

build-docker-image:
	docker build --tag $(IMAGE) .

push-docker-image:
	docker push $(IMAGE)

clean: stop
	rm -rf node_modules
	rm -rf client/resources/sqlui.js
	rm -rf vendor
	rm -rf .bundle
	rm -rf *.gem

start:
	docker compose up

start-detached:
	docker compose up --detach
	make await-healthy-server

stop:
	docker compose down
	@docker network rm sqlui_default 2> /dev/null || true

kill:
	@docker kill sqlui_server || true
	@docker kill sqlui_db || true
	@docker kill sqlui_node_chrome || true
	@docker kill sqlui_hub || true
	@docker network rm sqlui_default 2> /dev/null || true

start-db:
	docker compose up db

start-db-detached:
	docker compose up -d db

stop-db:
	docker compose down db

seed-db:
	docker exec --interactive sqlui_db mysql --host=db --protocol=tcp --user=root --password=root < sql/init.sql

seed-db-local:
	mysql --protocol=tcp --user=root --password=root < sql/init.sql

mysql:
	docker exec --interactive --tty sqlui_db mysql --user=root --password=root $(if $(QUERY),--execute "$(QUERY)",)

mysql-local:
	mysql --user=root --password=root $(if $(QUERY),--execute "$(QUERY)",)

docker-run: create-network
	@$(RUN_IMAGE) $(CMD)

start-server:
	docker compose up db server

start-server-detached:
	docker compose up --detach server

build-and-start-server-local: build-local
	bundle exec ruby ./bin/sqlui development_config.yml

start-server-local:
	$(RERUN) -- make build-and-start-server-local

start-hub:
	docker compose up hub

start-hub-detached:
	docker compose up --detach hub

start-node-chrome:
	docker compose up node-chrome

start-node-chrome-detached:
	docker compose up --detach node-chrome

test: create-network
	$(RUN) --env DB_HOST=db --publish 9090:9090 --name test $(IMAGE) bundle exec rspec $(if $(ARGS),$(ARGS),)

watch-test:
	$(RERUN) --dir spec make test

test-local:
	LOCAL=true bundle exec rspec $(if $(ARGS),$(ARGS),)

watch-test-local:
	$(RERUN) --dir spec make test-local $(if $(ARGS),ARGS=$(ARGS),)

start-test-stop: start-detached test stop

await-healthy-server:
	@for i in $$(seq 1 30); do \
    result="$$(docker inspect --format='{{if .State.Health.Status}}{{print .State.Health.Status}}{{end}}' sqlui_server 2>&1 || true)"; \
    [ "$$result" != "" ] && echo "$$result"; \
    if [ "$$result" = 'healthy' ]; then \
      exit 0; \
    fi; \
    if [ $$i -eq 30 ]; then \
      VERSION=$(VERSION) docker kill sqlui_server >/dev/null || true; \
      exit 1; \
    fi; \
    sleep 1; \
  done
