# Changes

## 0.1.21

- Fix bug in type mapping.
- Link app title to databases list.
- Fix broken saved query loading.

## 0.1.20

- Add execute and execute selection buttons.
- Add support for ctrl-shift-enter to execute the entire editor contents.
- Add support for executing more than one statement at once, for instance setting and using variables.
- Add app name to header.
- Add some error handling for app load and server requests.
- Some style changes.
- Fix bug where part of the result header was still displayed for an empty result.

## 0.1.19

- Add ability to configure full path to databases and database list.
- Add ability to name the server.

## 0.1.18

- Fix bug where going back to a previous search did not change results.
- Fix bug where metadata was cached and changes to DB were not reflected.

## 0.1.17

- No changes

## 0.1.16

- Fix broken table names in structure.
- Fix broken path in config.yml.
- Fix no structure when no indexes.

## 0.1.15

- Fix missing resources in Gem.

## 0.1.14

- New config format.

## 0.1.13

- No changes

## 0.1.12

- No new features. Fix broken release script.

## 0.1.11

- Add a server.

## 0.1.10

- Allow client to specify table_schema.

## 0.1.9

- Allow sql client to be specified as param.

## 0.1.8

- Add support for Mysql2.

## 0.1.7

- Fix bug where squish is called.

## 0.1.6

- Remove html_safe call. Clients should now do this themselves.

## 0.1.5

- Allow configuration of max rows.

## 0.1.4

- Fix bug causing requery and editor reset on back.

## 0.1.3

- Just some refactoring to serve separate js and css files. No new features.

## 0.1.2

- get and post methods instead of resource-specific methods (javascript, html, metadata, query)

## 0.1.1

- Cache metadata.
