.PHONY: *

RUN = docker run --rm --tty --interactive --env BUNDLE_APP_CONFIG=/sqlui/.bundle --network sqlui_default --volume `pwd`:/sqlui --workdir /sqlui
IMAGE = sqlui
RUN_IMAGE = $(RUN) $(IMAGE)

RERUN = ./scripts/rerun --dir bin --dir app --dir sql --file client/sqlui.js --file client/resources/sqlui.css --file client/resources/sqlui.html --file development_config.yml

DB_HOST ?= 127.0.0.1
DB_PORT ?= 3306

create-network:
	@docker network inspect sqlui_default >/dev/null 2>&1 || docker network create --driver bridge sqlui_default > /dev/null

install: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm install && bundle config set --local path vendor/bundle && bundle install'

update: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm update && bundle update'

update-local:
	npm update
	bundle config set --local path vendor/bundle
	bundle update

# Make sure to run `nvm use 19` first.
install-local:
	npm install
	bundle config set --local path vendor/bundle
	bundle install

build: create-network
	$(RUN_IMAGE) make build-local

build-local:
	rm -f client/resources/sqlui.js
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs
	chmod 444 client/resources/sqlui.js

lint: create-network
	$(RUN_IMAGE) bundle exec rubocop
	$(RUN_IMAGE) npx eslint client/*.js

lint-local:
	bundle exec rubocop
	npx eslint client/*.js

lint-fix: create-network
	$(RUN_IMAGE) bundle exec rubocop -A
	$(RUN_IMAGE) npx eslint client/*.js --fix

lint-fix-local:
	bundle exec rubocop -A
	npx eslint client/*.js --fix

build-docker-image:
	docker build --tag sqlui .

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

stop:
	docker compose down
	docker network rm sqlui_default || true

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
	DB_HOST=$(DB_HOST) DB_PORT=$(DB_PORT) bundle exec ruby ./bin/sqlui development_config.yml

start-server-local:
	$(RERUN) -- make build-and-start-server-local

start-hub:
	docker compose up hub node-chrome

start-hub-detached:
	docker compose up --detach hub node-chrome

test: create-network
	$(RUN_IMAGE) bundle exec rspec $(if $(ARGS),$(ARGS),)

watch-test:
	$(RERUN) spec make test

test-local:
	LOCAL=true bundle exec rspec $(if $(ARGS),$(ARGS),)

watch-test-local:
	$(RERUN) spec make test-local

start-test-stop: start-detached test stop
