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

### Running linters

- `rake lint` - Run the full suite of linters on the codebase and autocorrect.
- `rake security` - Run the suite of security scanners on the codebase.
- `rake ci` - Run all build steps performed in CI.

### Running a rails interactive console

- `rails console` -  runs an IRB like REPL in which all of the API's classes and environmental variables have been loaded.
