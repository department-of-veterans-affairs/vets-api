# frozen_string_literal: true

require 'pact/provider/rspec'
require 'service_consumers/provider_states'

Pact.service_provider 'VA.gov API' do
  honours_pact_with 'VA.gov' do
    # This example points to a local file, however, on a real project with a continuous
    # integration box, you would use a [Pact Broker](https://github.com/pact-foundation/pact_broker) or publish your pacts as artifacts,
    # and point the pact_uri to the pact published by the last successful build.

    pact_uri 'tmp/va.gov-va.gov_api.json'
  end
end
