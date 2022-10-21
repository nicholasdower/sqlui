.PHONY: *

RUN = docker run --rm --env BUNDLE_APP_CONFIG=/sqlui/.bundle --volume `pwd`:/sqlui --workdir /sqlui
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

start-db:
	./scripts/db-ready.sh

stop-db:
	docker compose down db

seed-db:
	docker exec -i sqlui_db mysql --user=developer --password=password --database=development < seeds.sql

mysql:
	docker exec -it sqlui_db mysql --user=root --password=root --database=development $(if $(QUERY),--execute "$(QUERY)",)

start-server:
	docker compose up --detach server

start-server-local:
	PORT=8080 APP_ENV=development bundle exec ruby ./bin/sqlui development_config_local.yml

unit-test:
	$(RUN_IMAGE) make unit-test-local

unit-test-local:
	bundle exec rspec --format doc spec/unit

integration-test:
	$(RUN_IMAGE) make integration-test-local

integration-test-local:
	bundle exec rspec --format doc spec/integration
