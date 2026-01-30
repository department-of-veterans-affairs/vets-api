# Ask VA API

Module providing Ask VA functionality within vets-api.

## Installation
Ensure the following line exists in the root project's Gemfile:

```ruby
gem 'ask_va_api', path: 'modules/ask_va_api'
```

Then install and setup:

```bash
bundle install
make db
```

## Zip/State Dev Seeding
Seed a minimal set of `std_states` and `std_zipcodes` records used by the Ask VA zip/state validation in native development.

- Dev-only: the task aborts unless the Rails environment is `development`.
- Requires DB tables `std_states` and `std_zipcodes` (created by normal migrations).

### Usage
Run from the vets-api project root:

```bash
bundle exec rails ask_va_api:seed:std_zip_state
```

### Reset
To clear previously seeded rows (only the predefined states/zipcodes) and reseed:

```bash
RESET=true bundle exec rails ask_va_api:seed:std_zip_state
```

### Verification
Quick checks in Rails console:

```bash
bundle exec rails console
```

```ruby
# Confirm seeded states exist
StdState.where(postal_name: %w[CA TX NY PA]).pluck(:postal_name, :id)

# Confirm a seeded zipcode exists
StdZipcode.find_by(zip_code: '90001')

# Confirm a zipcode/state match
ca = StdState.find_by(postal_name: 'CA')
StdZipcode.where(zip_code: '90001', state_id: ca.id).exists?
```

### References
- Rake task: `modules/ask_va_api/lib/tasks/ask_va_api/seed/std_zip_state.rake`
- Seed data: `modules/ask_va_api/lib/ask_va_api/seed/std_zip_state_records.rb`
- Models: `modules/income_limits/app/models/std_state.rb`, `modules/income_limits/app/models/std_zipcode.rb`

## License
This module is open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
