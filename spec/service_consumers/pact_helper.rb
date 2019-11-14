# frozen_string_literal: true

require 'pact/provider/rspec'

require 'service_consumers/provider_states'

# Ensure your provider application version enables you to trace back to an exact
# state of your provider codebase.
# The easiest way to do this is to include the build number (or a SHA) in your version.
provider_version = ENV['GIT_COMMIT'] || `git rev-parse --verify HEAD`
# publish_flag = ENV['PUBLISH_VERIFICATION_RESULTS'] == "true"

Pact.service_provider 'VA.gov API' do
  # This example points to a local file, however, on a real project with a continuous
  # integration box, you would use a [Pact Broker](https://github.com/pact-foundation/pact_broker) or publish your pacts as artifacts,
  # and point the pact_uri to the pact published by the last successful build.
  # honours_pact_with 'VA.gov' do
  #   pact_uri 'tmp/va.gov-va.gov_api.json'
  # end

  app_version provider_version
  publish_verification_results true

  honours_pacts_from_pact_broker do
    pact_broker_base_url 'http://host.docker.internal:9292'
  end
end
