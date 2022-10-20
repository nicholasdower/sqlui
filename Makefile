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
	rm resources/sqlui.js
	rm -rf vendor

.PHONY: clean-all
clean-all: clean
	rm config.yml
	rm *.gem

.PHONY: run
run:
	PORT=8080 APP_ENV=development bundle exec ruby ./bin/sqlui config.yml

.PHONY: clean
clean:
	git clean -fXd
