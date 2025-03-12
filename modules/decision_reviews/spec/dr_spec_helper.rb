# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
ENV['RACK_ENV'] ||= 'test' # Shrine uses this to determine log levels
require File.expand_path('../../../config/environment', __dir__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'statsd-instrument'
require 'statsd/instrument/matchers'
require 'rspec/rails'
require 'webmock/rspec'
require 'shoulda/matchers'
require 'support/stub_va_profile'
require 'support/mpi/stub_mpi'
require 'support/factory_bot'
require 'support/authenticated_session_helper'

WebMock.disable_net_connect!(allow_localhost: true)

# Helper function for testing changes to the global Settings object
# Pass in the particular settings object that you want to change,
# along with temporary values that should be set on that object.
# For example,
#
# with_settings(Settings.some_group, {foo: 'temp1', bar: 'temp2'}) do
#   expect(something).to equal(2)
# end
def with_settings(settings, temp_values)
  old_settings = temp_values.keys.index_with { |k| settings[k] }

  # The `Config` object doesn't support `.merge!`, so manually copy
  # the updated values.
  begin
    temp_values.each do |k, v|
      settings[k] = v
    end

    yield
  ensure
    old_settings.each do |k, v|
      settings[k] = v
    end
  end
end

ActiveRecord::Migration.maintain_test_schema!

FactoryBot::SyntaxRunner.class_eval do
  include RSpec::Mocks::ExampleMethods
end

RSpec.configure do |config|
  # Adding support for url_helper
  config.include Rails.application.routes.url_helpers

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  ## authentication_session_helper
  config.include AuthenticatedSessionHelper, type: :request
  config.include AuthenticatedSessionHelper, type: :controller

  config.include StatsD::Instrument::Matchers

  config.include FactoryBot::Syntax::Methods

  config.before :each, type: :controller do
    request.host = Settings.hostname
  end
end

Gem::Deprecate.skip = true

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
