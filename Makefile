.PHONY: install
install:
	npm install
	bundle install

.PHONY: build
build:
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs

.PHONY: update-npm
update-npm:
	npm install -g npm@latest

.PHONY: clean
clean:
	rm -rf node_modules
	rm resources/sqlui.js
