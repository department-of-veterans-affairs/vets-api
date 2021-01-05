## Running the app Natively


To run vets-api and its redis and postgres dependencies run the following command from within the repo you cloned 
in the above steps.

```
foreman start -m all=1,clamd=0,freshclam=0
```

You should then be able to navigate to [http://localhost:3000/v0/status](http://localhost:3000/v0/status) in your
browser and start interacting with the API. Changes to the source in your local
directory will be reflected automatically via a docker volume mount, just as
they would be when running rails directly.


### Running tests

- `bundle exec rake spec` - Run the entire test suite  ( for `rspec spec`). Test coverage statistics are in `coverage/index.html` or in [CodeClimate](https://codeclimate.com/github/department-of-veterans-affairs/vets-api/code)
- `make guard` - Run the guard test server that reruns your tests after files are saved. Useful for TDD!

### Running tests in parallel
- `RAILS_ENV=test bundle exec rake db:reset` - Set up your test database properly first. This just makes sure if your existing test database is named differently than what is expected, it will be resolved first
- `bundle exec rake parallel:setup` - This prepares all of the test databases. It will create a test database for each processor on your computer
- `bundle exec rake parallel:spec` - This runs the entire test suite. Optionally, a folder path can be given as a parameter. Each file is assigned a processor, so it probably doesn't make sense to pass an individual file to run it in parallel

### Running linters

- `rake lint` - Run the full suite of linters on the codebase and autocorrect.
- `rake security` - Run the suite of security scanners on the codebase.
- `rake ci` - Run all build steps performed in CI.

### Running a rails interactive console

- `rails console` -  runs an IRB like REPL in which all of the API's classes and environmental variables have been loaded.
