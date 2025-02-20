
# Contributing to active_record-tenanted

## Test scenarios

Most tests rely on one or more "scenarios" being loaded. A "scenario" is a combination of:

- database configuration
- model configuration

and the `database.yml` and model files are all located under `test/scenarios/`.

In the unit testing suite, there are some scenario helpers (e.g., `for_each_scenario(&block)`) in `test/test_helper.rb` that allow us to run the tests under one or more scenarios using nested `describe` blocks.


## Running unit tests

Unit tests are run with `bin/test`. The test files are all under `test/unit/`.


## Running integration tests

The integration testing suite is run via the command `bin/test-integration`, which:

- for each scenario
  - makes a copy of the `test/smarty/` app
  - write the scenario files: database.yml, models, and migrations
  - copy the config and test files from `test/integration/`
  - setup the databases
  - run the integration tests
