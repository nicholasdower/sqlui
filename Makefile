.PHONY: install
install:
	npm install

.PHONY: build
build:
	./node_modules/rollup/dist/bin/rollup --config ./rollup.config.js --bundleConfigAsCjs

.PHONY: update-npm
	npm install -g npm@latest
