# frozen_string_literal: true

# ensure pacts run in test
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../config/environment', __dir__)
require 'pact/provider/rspec'
require 'rspec/rails'
require 'support/factory_bot'
require 'support/authenticated_session_helper'
require 'support/mpi/stub_mpi'
require 'support/stub_emis'
require 'support/stub_session'
require 'support/va_profile/stub_vet360'
require 'support/vcr'
Dir.glob(File.expand_path('provider_states_for/*.rb', __dir__)).sort.each(&method(:require))

VCR.configure do |c|
  # PACT requests are performed before insert_cassette is invoked
  c.allow_http_connections_when_no_cassette = true
  c.default_cassette_options = {
    record: :none
  }
end

# Ensure your provider application version enables you to trace back to an exact
# state of your provider codebase.
# The easiest way to do this is to include the build number (or a SHA) in your version.
git_sha = (ENV['GIT_COMMIT'] || `git rev-parse --verify HEAD`).chomp
git_branch = (ENV['GIT_BRANCH'] || `git rev-parse --abbrev-ref HEAD`).chomp
# don't publish results if running in local development env
publish_flag = ENV['PUBLISH_PACT_VERIFICATION_RESULTS'] == 'true' || !Rails.env.development?

Pact.configure do |config|
  config.include AuthenticatedSessionHelper
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.before do |example|
    stub_mpi unless example.metadata[:skip_mvi]
    stub_emis unless example.metadata[:skip_emis]
    stub_vet360 unless example.metadata[:skip_vet360]

    $redis.flushall
  end
end

FactoryBot::SyntaxRunner.class_eval do
  include RSpec::Mocks::ExampleMethods
end

Pact.service_provider 'VA.gov API' do
  # This example points to a local file, however, on a real project with a continuous
  # integration box, you would use a [Pact Broker](https://github.com/pact-foundation/pact_broker)
  # or publish your pacts as artifacts, and point the pact_uri to the pact published by the last successful build.
  # honours_pact_with 'HCA Post' do
  #   pact_uri 'tmp/hca-va.gov_api.json'
  # end

  # # temporarily define the url or else we will get failing verification
  # honours_pact_with 'Search' do
  #   pact_uri 'https://dev.va.gov/_vfs/pact-broker/pacts/provider/VA.gov%20API/consumer/Search/latest'
  # end

  honours_pacts_from_pact_broker do
    pact_broker_base_url 'https://dev.va.gov/_vfs/pact-broker/',
                         {
                           username: ENV['PACT_BROKER_BASIC_AUTH_USERNAME'],
                           password: ENV['PACT_BROKER_BASIC_AUTH_PASSWORD']
                         }
    # When using WIP pacts feature,
    # it's best to turn on pending pacts so that any WIP pact failures
    # don't cause the build to fail
    enable_pending true

    # When verifying pacts, the verification task can be configured
    # to include all "work in progress" pacts (as well as the pacts that you
    # specify by tag, like master or prod).
    include_wip_pacts_since '2020-09-01'

    # Optionally specify the consumer version tags for the pacts you want to verify
    # This will verify the latest pact with the tag `master`
    # consumer_version_tags ['pact-search', 'pact-user', 'pact-hca']
    consumer_version_tags ['master']
  end

  app_version git_sha
  app_version_tags git_branch
  publish_verification_results publish_flag if ENV['CI']
end
