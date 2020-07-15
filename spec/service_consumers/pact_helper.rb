# frozen_string_literal: true

# ensure pacts run in test
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../config/environment', __dir__)
require 'pact/provider/rspec'
require 'service_consumers/provider_states'
require 'support/vcr'

VCR.configure do |c|
  # PACT requests are performed before insert_cassette is invoked
  c.allow_http_connections_when_no_cassette = true
end

# Ensure your provider application version enables you to trace back to an exact
# state of your provider codebase.
# The easiest way to do this is to include the build number (or a SHA) in your version.
provider_version = ENV['GIT_COMMIT'] || `git rev-parse --verify HEAD`
# publish_flag = ENV['PUBLISH_VERIFICATION_RESULTS'] == "true"

Pact.service_provider 'VA.gov API' do
  # This example points to a local file, however, on a real project with a continuous
  # integration box, you would use a [Pact Broker](https://github.com/pact-foundation/pact_broker)
  # or publish your pacts as artifacts, and point the pact_uri to the pact published by the last successful build.
  # honours_pact_with 'HCA Post' do
  #   pact_uri 'tmp/hca-va.gov_api.json'
  # end

  app_version provider_version
  publish_verification_results true

  honours_pacts_from_pact_broker do
    pact_broker_base_url 'https://vagov-pact-broker.herokuapp.com'
  end
end
