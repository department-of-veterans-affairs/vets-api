# frozen_string_literal: true

require 'webmock'
include WebMock::API

WebMock.enable!
WebMock.allow_net_connect!

Pact.provider_states_for 'HCA' do
  provider_state 'enrollment service is up' do
    set_up do
      response_body_stub =
        YAML.load_file(
          'spec/support/vcr_cassettes/hca/submit_anon.yml'
        )['http_interactions'][0]['response']['body']['string']

      stub_request(:post, Settings.hca.endpoint).to_return(body: response_body_stub)
    end

    tear_down do
      # Any tear down steps to clean up the provider state
    end
  end
end

Pact.provider_states_for 'Search' do
  provider_state 'multiple matching results exist' do
    no_op
    # set_up do
    #   VCR.insert_cassette('search/page_1')
    # end
    #
    # tear_down do
    #   VCR.eject_cassette
    # end
  end
end
