.PHONY: *

RUN = docker run --rm --tty --interactive --env BUNDLE_APP_CONFIG=/sqlui/.bundle --network sqlui_default --volume `pwd`:/sqlui --workdir /sqlui
IMAGE = sqlui
RUN_IMAGE = $(RUN) $(IMAGE)

create-network:
	@docker network inspect sqlui_default >/dev/null 2>&1 || docker network create --driver bridge sqlui_default > /dev/null

install: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm install && bundle install'

update: create-network
	$(RUN_IMAGE) /bin/bash -c 'npm update && bundle update'

update-local:
	npm update
	bundle config set --local path vendor/bundle
	bundle update

install-local:
	npm install
	bundle config set --local path vendor/bundle
	bundle install

build: create-network
	$(RUN_IMAGE) make build-local

build-local:
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs

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

start-rollup:
	docker compose up --detach rollup

start-rollup-local:
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs --watch

build-docker-image:
	docker build --tag sqlui .

clean: stop
	rm -rf node_modules
	rm -rf client/resources/sqlui.js
	rm -rf vendor
	rm -rf .bundle
	rm *.gem

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
	docker compose up db rollup server

start-server-detached:
	docker compose up --detach server

start-server-local:
	DB_HOST=127.0.0.1 DB_PORT=3306 ./scripts/rerun bundle exec ruby ./bin/sqlui development_config.yml

start-hub:
	docker compose up hub node-chrome

start-hub-detached:
	docker compose up --detach hub node-chrome

test: create-network
	$(RUN_IMAGE) bundle exec rspec $(if $(ARGS),$(ARGS),)

start-test-stop: start-detached test stop

test-local:
	LOCAL=true bundle exec rspec $(if $(ARGS),$(ARGS),)
