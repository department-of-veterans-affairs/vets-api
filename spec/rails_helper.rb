# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
ENV['RACK_ENV'] ||= 'test' # Shrine uses this to determine log levels
require File.expand_path('../config/environment', __dir__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'statsd-instrument'
require 'statsd/instrument/matchers'
require 'rspec/rails'
require 'webmock/rspec'
require 'shoulda/matchers'
require 'sidekiq/semantic_logging'
require 'sidekiq/error_tag'
require 'support/stub_va_profile'
require 'support/mpi/stub_mpi'
require 'support/va_profile/stub_vaprofile_user'
require 'support/factory_bot'
require 'support/serializer_spec_helper'
require 'support/validation_helpers'
require 'support/model_helpers'
require 'support/helpers/fhir_resource_builder'
require 'support/authenticated_session_helper'
require 'support/aws_helpers'
require 'support/vcr'
require 'support/mdot_helpers'
require 'support/financial_status_report_helpers'
require 'support/poa_stub'
require 'support/sm_spec_helper'
require 'support/vcr_multipart_matcher_helper'
require 'support/request_helper'
require 'support/uploader_helpers'
require 'support/sign_in'
require 'super_diff/rspec-rails'
require 'super_diff/active_support'
require './spec/support/default_configuration_helper'

WebMock.disable_net_connect!(allow_localhost: true)
SemanticLogger.sync!

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

VCR::MATCH_EVERYTHING = { match_requests_on: %i[method uri headers body] }.freeze

module VCR
  def self.all_matches
    %i[method uri body]
  end
end

VCR.configure(&:configure_rspec_metadata!)

VCR.configure do |c|
  c.before_record(:force_utf8) do |interaction|
    interaction.response.body.force_encoding('UTF-8')
  end
end

VCR.configure do |config|
  ignored_uris = [
    'http://169.254.169.254/latest/api/token' # ec2
  ]

  config.ignore_request do |request|
    ignored_uris.include?(request.uri)
  end
end

Datadog.configure do |c|
  c.tracing.enabled = false
end

ActiveRecord::Migration.maintain_test_schema!

require 'sidekiq/testing'
Sidekiq::Testing.fake!
Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::SemanticLogging
  chain.add SidekiqStatsInstrumentation::ServerMiddleware
  chain.add Sidekiq::ErrorTag
  chain.add Sidekiq::Batch::Server if defined?(Sidekiq::Batch)
end

require 'shrine/storage/memory'

Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new
}

CarrierWave.root = Rails.root.join('spec', 'support', "uploads#{ENV.fetch('TEST_ENV_NUMBER', nil)}")

FactoryBot::SyntaxRunner.class_eval do
  include RSpec::Mocks::ExampleMethods
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_paths = Array(Rails.root / 'spec/fixtures')

  config.include(ValidationHelpers, type: :model)
  %i[controller model].each do |type|
    config.include(ModelHelpers, type:)
  end
  config.include(FhirResourceBuilder, type: :model)
  config.include(SAML, type: :controller)
  config.include(AwsHelpers, type: :aws_helpers)
  config.include(UploaderHelpers, uploader_helpers: true)

  %i[controller mdot_helpers request].each do |type|
    config.include(MDOTHelpers, type:)
  end

  # Allows setting of filenet_id in the FinancialStatusReport model
  config.include FinancialStatusReportHelpers, type: :controller
  config.include FinancialStatusReportHelpers, type: :service
  config.include FinancialStatusReportHelpers, type: :request

  # Adding support for url_helper
  config.include Rails.application.routes.url_helpers

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods

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

  # set `:type` for serializers directory
  config.define_derived_metadata(file_path: Regexp.new('/spec/serializers/')) do |metadata|
    metadata[:type] = :serializer
  end

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # serializer_spec_helper
  config.include SerializerSpecHelper, type: :serializer

  # authentication_session_helper
  config.include AuthenticatedSessionHelper, type: :request
  config.include AuthenticatedSessionHelper, type: :controller

  # ability to test options
  config.include RequestHelper, type: :request

  config.include StatsD::Instrument::Matchers

  config.before :each, type: :controller do
    request.host = Settings.hostname
  end

  config.before do |example|
    stub_mpi unless example.metadata[:skip_mvi]
    stub_va_profile unless example.metadata[:skip_va_profile]
    stub_vaprofile_user unless example.metadata[:skip_va_profile_user]
    Sidekiq::Job.clear_all
  end

  # clean up carrierwave uploads
  # https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Cleanup-after-your-Rspec-tests
  config.after(:all) do
    FileUtils.rm_rf(Rails.root.glob("spec/support/uploads#{ENV.fetch('TEST_ENV_NUMBER', nil)}")) if Rails.env.test?
  end
end

BGS.configure do |config|
  config.logger = Rails.logger
end

Gem::Deprecate.skip = true

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
