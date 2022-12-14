## 0.1.60

- Display entire error in status. Show elipsis conditionally.
- Fix result streaming.
- Don't exceed max result bytes.
- Handle more JavaScript errors.
- Clicking a result cell now displays all contents in a popup.
- Handle newlines in cell contents.

## 0.1.59

- Focus editor on click.
- Add jump button to pagination.

## 0.1.58

- Fix status message styling.

## 0.1.57

- Resize columns to fit on page change.
- Improve column resize performance.
- Add first and last pagination buttons.
- Far better query splitting.
- Increase max rows to 50,000.
- Render decimals properly.
- Fix formatting on truncated row count.

## 0.1.56

- Resize columns to fit on page change.
- Improve column resize performance.

## 0.1.55

- Prevent horizontal scrollbar caused by fill column taking up too much space.

## 0.1.54

- Align cell content based on type.
- Allow resizing of columns.
- Cache css, js and favicon.

## 0.1.53

- No changes.

## 0.1.52

- Add favicon to DB list.
- Improve alias autocomplete.
- Fix bug in displaying an empty result.
- Add Prometheus.
- Add support for Airbrake error reporting.

## 0.1.51

- Add favicon to DB list.

## 0.1.50

- No changes.

## 0.1.49

- Use a map for column links and joins to allow for YAML anchor overrides.

## 0.1.48

- Better SQL parser which allows for semicolons in quotes and comments.
- Add favicon
- Custom error pages
- Fix bug where autocomplete displayed under table head.
- Add support for column links.

## 0.1.47

- Results are now streamed to the browser.
- Add ability to boost a table in autocomplete.

## 0.1.46

- No changes.
- No changes.

## 0.1.45

- No changes.
- No changes.

## 0.1.44

- No changes.
- No changes.

## 0.1.43

- No changes.

## 0.1.42

- Add ability to download query results.
- Increase max rows to 10,000.
- Fix formatting on row count, use commas.

## 0.1.41

- Add support for canned joins.
- Add support for duplicate columns in results.
- Sort columns in structure by ordinal_position.
- Allow aliases in config YAML.
- Autocomplete qualified table names with aliases.

## 0.1.40

- No changes.

## 0.1.39

- Add support for default table aliases.
- Fix bug where tables/columns not cleared when changing schemas in structure tab.

## 0.1.38

- Stop logging content copied to clipboard.

## 0.1.37

- No changes.

## 0.1.36

- Fix bug where structure tab overflowed.
- Fix bug where title wrapped.
- Make run button a dropdown.
- Add copy to clipboard (CSV or TSV).

## 0.1.35

- No changes.

## 0.1.34

- No changes.

## 0.1.33

- No changes.

## 0.1.32

- Use Cmd-Enter to submit on Mac.
- Add binding for Shift-Enter to insert a new line.
- Display entire server error in console.
- Add autocomplete for tables and columns.
- Fix folding bug where strange characters were displayed.
- Autocapitalize and use MySQL sytax instead of default SQL.

## 0.1.31

- Fix bug in saved query description newlines.

## 0.1.30

- Display query execution time in status.
- Add support for setting SQL variables with query params.

## 0.1.29

- Move port and environment into config. No more environment variables.
- Fix bug preventing running queries unless referrer set.
- Better spinner display logic.
- Fix broken cancel button. Was resulting in a missing status bar.
- Display a timer when waiting for results.

## 0.1.28

- Use APP_ENV and APP_PORT instead of SERVER_ENV and SERVER_PORT.
- Add "SQLUI" to database list title.

## 0.1.27

- Fix bug in saved file count.

## 0.1.26

- Add cancel button.
- Queries are no longer automatically run.
- Add view and run options to saved query list.

## 0.1.25

- Show spinners.
- Add ability to link to query without running.
- Prettify selection param. Only use when running selection.
- Update url scheme, e.g. /query instead of tab=query.
- Redirect / to app.

## 0.1.24

- Just some style updates.

## 0.1.23

- Fix bug for query without semicolon.

## 0.1.22

- Show database name in title.

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
