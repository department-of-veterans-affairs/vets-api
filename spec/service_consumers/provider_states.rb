# frozen_string_literal: true

require 'webmock'
include WebMock::API

WebMock.enable!

Pact.provider_states_for 'VA.gov' do
  provider_state 'enrollment service is up' do
    set_up do
      stub_request(:post, Settings.hca.endpoint).to_return(
        body: '<?xml version=\'1.0\' encoding=\'UTF-8\'?><S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/"><S:Body><submitFormResponse xmlns:ns2="http://jaxws.webservices.esr.med.va.gov/schemas" xmlns="http://va.gov/schema/esr/voa/v1"><status>100</status><formSubmissionId>40124668140</formSubmissionId><message><type>Form successfully received for EE processing</type></message><timeStamp>2016-05-25T04:59:39.345-05:00</timeStamp></submitFormResponse></S:Body></S:Envelope>'
      )
    end

    tear_down do
      # Any tear down steps to clean up the provider state
    end
  end
end
