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
  let(:scopes) { %w[claim.write] }

  describe '#526' do
    let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json')) }

    it 'should return a successful response with all the data' do
      with_okta_user(scopes) do |auth_header|
        post '/services/claims/v1/forms/526', params: JSON.parse(data), headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(parsed['data']['type']).to eq('claims_api_auto_established_claims')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    it 'should create the sidekick job' do
      with_okta_user(scopes) do |auth_header|
        expect(ClaimsApi::ClaimEstablisher).to receive(:perform_async)
        post '/services/claims/v1/forms/526', params: JSON.parse(data), headers: headers.merge(auth_header)
      end
    end

    it 'should build the auth headers' do
      with_okta_user(scopes) do |auth_header|
        auth_header_stub = instance_double('EVSS::DisabilityCompensationAuthHeaders')
        expect(EVSS::DisabilityCompensationAuthHeaders).to receive(:new) { auth_header_stub }
        expect(auth_header_stub).to receive(:add_headers)
        post '/services/claims/v1/forms/526', params: JSON.parse(data), headers: headers.merge(auth_header)
      end
    end
  end

  describe '#upload_supporting_documents' do
    let(:auto_claim) { create(:auto_established_claim) }
    let(:params) do
      { 'attachment': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
    end

    it 'should increase the supporting document count' do
      with_okta_user(scopes) do |auth_header|
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        count = auto_claim.supporting_documents.count
        post("/services/claims/v1/forms/526/#{auto_claim.id}/attachments",
             params: params, headers: headers.merge(auth_header))
        auto_claim.reload
        expect(auto_claim.supporting_documents.count).to eq(count + 1)
      end
    end
  end
end
