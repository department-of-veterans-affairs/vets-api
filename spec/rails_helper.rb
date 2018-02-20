# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
ENV['RACK_ENV'] ||= 'test' # Shrine uses this to determine log levels
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'spec_helper'
require 'statsd-instrument'
require 'statsd/instrument/matchers'
require 'rspec/rails'
require 'webmock/rspec'
require 'support/factory_girl'
require 'support/serializer_spec_helper'
require 'support/xml_matchers'
require 'support/validation_helpers'
require 'support/model_helpers'
require 'support/authenticated_session_helper'
require 'support/aws_helpers'
require 'support/request_helper'
require 'common/exceptions'

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
  old_settings = temp_values.keys.map { |k| [k, settings[k]] }.to_h

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

VCR::MATCH_EVERYTHING = { match_requests_on: %i[method uri headers body] }.freeze

VCR.configure do |c|
  c.cassette_library_dir = 'spec/support/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data('<PENSIONS_TOKEN>') { Settings.pension_burial.upload.token }
  c.filter_sensitive_data('<APP_TOKEN>') { Settings.mhv.rx.app_token }
  c.filter_sensitive_data('<EVSS_BASE_URL>') { Settings.evss.url }
  c.filter_sensitive_data('<EVSS_AWS_BASE_URL>') { Settings.evss.aws.url }
  c.filter_sensitive_data('<GIDS_URL>') { Settings.gids.url }
  c.filter_sensitive_data('<MHV_HOST>') { Settings.mhv.rx.host }
  c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { Settings.mhv.sm.app_token }
  c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.sm.host }
  c.filter_sensitive_data('<MVI_URL>') { Settings.mvi.url }
  c.filter_sensitive_data('<PRENEEDS_HOST>') { Settings.preneeds.host }
  c.filter_sensitive_data('<PD_TOKEN>') { Settings.maintenance.pagerduty_api_token }
  c.before_record do |i|
    %i[response request].each do |env|
      next unless i.send(env).headers.keys.include?('Token')
      i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
    end
  end
end

ActiveRecord::Migration.maintain_test_schema!

require 'sidekiq/testing'
Sidekiq::Testing.fake!
Sidekiq::Logging.logger = nil

require 'shrine/storage/memory'

Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new
}

CarrierWave.root = Rails.root.join('spec', 'support', 'uploads')

FactoryBot::SyntaxRunner.class_eval do
  include RSpec::Mocks::ExampleMethods
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = Rails.root.join('spec', 'fixtures')

  config.include(ValidationHelpers, type: :model)
  %i[controller model].each do |type|
    config.include(ModelHelpers, type: type)
  end
  config.include(SAML, type: :controller)
  config.include(AwsHelpers, type: :aws_helpers)

  # Adding support for url_helper
  config.include Rails.application.routes.url_helpers

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # serializer_spec_helper
  config.include SerializerSpecHelper, type: :serializer

  # authentication_session_helper
  config.include AuthenticatedSessionHelper, type: :request

  # ability to test options
  config.include RequestHelper, type: :request

  config.include StatsD::Instrument::Matchers

  config.before(:each) do |example|
    stub_mvi unless example.metadata[:skip_mvi]
    stub_emis unless example.metadata[:skip_emis]
    Sidekiq::Worker.clear_all
  end

  # clean up carrierwave uploads
  # https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Cleanup-after-your-Rspec-tests
  config.after(:all) do
    FileUtils.rm_rf(Dir[Rails.root.join('spec', 'support', 'uploads')]) if Rails.env.test?
  end
end
