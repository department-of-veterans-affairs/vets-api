# frozen_string_literal: true
# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
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
require 'support/saml/authn_request_helper'
require 'support/authenticated_session_helper'
require 'support/aws_helpers'
require 'common/exceptions'

WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |c|
  c.cassette_library_dir = 'spec/support/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data('<MHV_SM_HOST>') { ENV['MHV_SM_HOST'] }
  c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { ENV['MHV_SM_APP_TOKEN'] }
  c.filter_sensitive_data('<MHV_HOST>') { ENV['MHV_HOST'] }
  c.filter_sensitive_data('<APP_TOKEN>') { ENV['MHV_APP_TOKEN'] }
  c.filter_sensitive_data('<MVI_URL>') { ENV['MVI_URL'] }
  c.filter_sensitive_data('<EVSS_BASE_URL>') { ENV['EVSS_BASE_URL'] }
  c.before_record do |i|
    %i(response request).each do |env|
      next unless i.send(env).headers.keys.include?('Token')
      i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
    end
  end
end

ActiveRecord::Migration.maintain_test_schema!

require 'sidekiq/testing'
Sidekiq::Testing.fake!
Sidekiq::Logging.logger = nil

CarrierWave.root = "#{Rails.root}/spec/support/uploads/"

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.include(ValidationHelpers, type: :model)
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

  config.include StatsD::Instrument::Matchers

  config.before(:each) do
    Sidekiq::Worker.clear_all
  end

  # clean up carrierwave uploads
  # https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Cleanup-after-your-Rspec-tests
  config.after(:all) do
    if Rails.env.test?
      FileUtils.rm_rf(Dir["#{Rails.root}/spec/support/uploads"])
    end
  end
end
