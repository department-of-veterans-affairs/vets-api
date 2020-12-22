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
require 'sidekiq/semantic_logging'
require 'sidekiq/error_tag'
require 'support/mpi/stub_mpi'
require 'support/stub_evss_pciu'
require 'support/vet360/stub_vet360'
require 'support/factory_bot'
require 'support/serializer_spec_helper'
require 'support/validation_helpers'
require 'support/model_helpers'
require 'support/authenticated_session_helper'
require 'support/aws_helpers'
require 'support/vcr'
require 'support/mdot_helpers'
require 'support/poa_stub'
require 'support/pdf_fill_helper'
require 'support/vcr_multipart_matcher_helper'
require 'support/request_helper'
require 'support/uploader_helpers'
require 'super_diff/rspec-rails'
require 'super_diff/active_support'
require './spec/support/default_configuration_helper'

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

ActiveRecord::Migration.maintain_test_schema!

require 'sidekiq/testing'
Sidekiq::Testing.fake!
Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::SemanticLogging
  chain.add Sidekiq::ErrorTag
end

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
  config.include(UploaderHelpers, uploader_helpers: true)

  %i[controller mdot_helpers request].each do |type|
    config.include(MDOTHelpers, type: type)
  end

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

  %i[model controller request].each do |type|
    config.include PdfFillHelper, type: type
  end

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
    stub_emis unless example.metadata[:skip_emis]
    stub_vet360 unless example.metadata[:skip_vet360]

    Sidekiq::Worker.clear_all
  end

  # clean up carrierwave uploads
  # https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Cleanup-after-your-Rspec-tests
  config.after(:all) do
    FileUtils.rm_rf(Dir[Rails.root.join('spec', 'support', 'uploads')]) if Rails.env.test?
  end
end
