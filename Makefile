.PHONY: *

RUN = docker run --rm --tty --interactive --env BUNDLE_APP_CONFIG=/sqlui/.bundle --network sqlui_default --volume `pwd`:/sqlui --workdir /sqlui
IMAGE = sqlui
RUN_IMAGE = $(RUN) $(IMAGE)

install:
	$(RUN_IMAGE) make install-local

install-local:
	npm install
	bundle config set --local path vendor/bundle
	bundle install

build:
	$(RUN_IMAGE) make build-local

build-local:
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs

build-docker-image:
	docker build --tag sqlui .

clean:
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

start-db:
	./scripts/db-ready.sh

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

docker-run:
	$(RUN_IMAGE) $(CMD)

start-server:
	docker compose up server

start-server-detached:
	docker compose up --detach server

start-server-local:
	bundle exec ruby ./bin/sqlui development_config_local.yml

test:
	$(RUN_IMAGE) bundle exec rspec

test-local:
	LOCAL=true bundle exec rspec
