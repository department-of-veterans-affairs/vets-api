# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796043735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-VA-EDIPI': '1007697216',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-User': 'adhoc.test.user',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json')) }

  it 'should return a successful response with all the data' do
    post '/services/claims/v0/forms/526', params: JSON.parse(data), headers: headers
    parsed = JSON.parse(response.body)
    expect(parsed['data']['type']).to eq('claims_api_auto_established_claims')
    expect(parsed['data']['attributes']['status']).to eq('pending')
  end

  it 'should create the sidekick job' do
    expect(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
    post '/services/claims/v0/forms/526', params: JSON.parse(data), headers: headers
  end

  it 'should build the auth headers' do
    auth_header_stub = instance_double('EVSS::DisabilityCompensationAuthHeaders')
    expect(EVSS::DisabilityCompensationAuthHeaders).to receive(:new) { auth_header_stub }
    expect(auth_header_stub).to receive(:add_headers)
    post '/services/claims/v0/forms/526', params: JSON.parse(data), headers: headers
  end
end
