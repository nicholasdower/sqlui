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

lint-local:
	bundle exec rubocop

lint-fix: create-network
	$(RUN_IMAGE) bundle exec rubocop -A

lint-fix-local:
	bundle exec rubocop -A

start-rollup:
	docker compose up --detach rollup

start-rollup-local:
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs

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
	docker compose up -d db-ready

stop-db:
	docker compose down db

seed-db:
	docker exec --interactive sqlui_db mysql --host=db --protocol=tcp --user=developer --password=password --database=development < seeds.sql

seed-db-local:
	mysql --user=developer --password=password --database=development < seeds.sql

mysql:
	docker exec --interactive --tty sqlui_db mysql --host=db --protocol=tcp --user=developer --password=password --database=development $(if $(QUERY),--execute "$(QUERY)",)

mysql-local:
	mysql --host=localhost --protocol=tcp --user=developer --password=password --database=development $(if $(QUERY),--execute "$(QUERY)",)

docker-run: create-network
	@$(RUN_IMAGE) $(CMD)

start-server:
	docker compose up db db-ready rollup server

start-server-detached:
	docker compose up --detach server

start-server-local:
	./scripts/rerun bundle exec ruby ./bin/sqlui development_config_local.yml

test: create-network
	$(RUN_IMAGE) bundle exec rspec

test-local:
	LOCAL=true bundle exec rspec
