# frozen_string_literal: true

# ensure pacts run in test
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../config/environment', __dir__)
require 'pact/provider/rspec'
require 'rspec/rails'
require 'support/factory_bot'
require 'support/authenticated_session_helper'
require 'support/mvi/stub_mvi'
require 'support/stub_emis'
require 'support/stub_session'
require 'support/vet360/stub_vet360'
require 'support/vcr'
Dir.glob(File.expand_path('provider_states_for/*.rb', __dir__), &method(:require))

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
  config.before do |example|
    stub_mvi unless example.metadata[:skip_mvi]
    stub_emis unless example.metadata[:skip_emis]
    stub_vet360 unless example.metadata[:skip_vet360]
  end
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
  #   pact_uri 'https://vagov-pact-broker.herokuapp.com/pacts/provider/VA.gov%20API/consumer/Search/latest'
  # end

  honours_pacts_from_pact_broker do
    pact_broker_base_url 'https://vagov-pact-broker.herokuapp.com'
  end

  app_version git_sha
  app_version_tags git_branch
  publish_verification_results publish_flag
end
