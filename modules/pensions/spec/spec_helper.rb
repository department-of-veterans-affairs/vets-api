# frozen_string_literal: true

require 'rspec/rails'

RSpec.configure { |config| config.use_transactional_fixtures = true }

# By default run SimpleCov, but allow an environment variable to disable.
unless ENV['NOCOVERAGE']
  require 'simplecov'

  SimpleCov.start 'rails' do
    track_files '**/{app,lib}/**/*.rb'

    add_filter 'app/swagger'

    if ENV['CI']
      SimpleCov.minimum_coverage 90
      SimpleCov.refuse_coverage_drop
    end
  end
end
