.PHONY: install
install:
	npm install
	bundle config set --local path vendor/bundle
	bundle install

.PHONY: build
build:
	bundle config set --local path vendor/bundle
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs

.PHONY: update-npm
update-npm:
	npm install -g npm@latest

.PHONY: clean
clean:
	rm -rf node_modules
	rm -rf client/resources/sqlui.js
	rm -rf vendor
	rm -rf .bundle

.PHONY: clean-all
clean-all: clean
	rm config.yml
	rm *.gem

.PHONY: start-db
start-db:
	docker compose up --detach db

.PHONY: stop-db
stop-db:
	docker compose down db

.PHONY: seed-db
seed-db:
	docker exec -i sqlui_db mysql --user=developer --password=password --database=development < seeds.sql

.PHONY: start
start:
	PORT=8080 APP_ENV=development bundle exec ruby ./bin/sqlui config.yml

.PHONY: test
test:
	bundle exec rspec --format doc
