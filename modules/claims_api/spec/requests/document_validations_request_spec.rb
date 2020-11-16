# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Document Validations Requests', type: :request do
  describe 'an upload request' do
    let(:headers) do
      { 'X-VA-SSN': '796-04-3735',
        'X-VA-First-Name': 'WESLEY',
        'X-VA-Last-Name': 'FORD',
        'X-VA-EDIPI': '1007697216',
        'X-Consumer-Username': 'TestConsumer',
        'X-VA-User': 'adhoc.test.user',
        'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
        'X-VA-LOA' => '3',
        'X-VA-Gender': 'M' }
    end
    let(:auto_claim) { create(:auto_established_claim) }

    context 'with a large pdf' do
      let(:params) do
        { 'attachment': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/18x22.pdf") }
      end

      # TODO: uncomment when validation is fixed
      xit it 'returns an error if the file is too large' do
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        post "/services/claims/v0/forms/526/#{auto_claim.id}/attachments", params: params, headers: headers
        expect(response.status).to eq(422)
      end
    end

    context 'with a normal pdf' do
      let(:params) do
        { 'attachment': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
      end

      it 'returns an success' do
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        post "/services/claims/v0/forms/526/#{auto_claim.id}/attachments", params: params, headers: headers
        expect(response.status).to eq(200)
      end
    end

    context 'with a non pdf' do
      let(:params) do
        path = Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/form_2122_json_api.json")
        { 'attachment': path }
      end

      # TODO: uncomment when validation is fixed
      xit it 'returns a failure' do
        allow_any_instance_of(ClaimsApi::SupportingDocumentUploader).to receive(:store!)
        post "/services/claims/v0/forms/526/#{auto_claim.id}/attachments", params: params, headers: headers
        expect(response.status).to eq(422)
      end
    end
  end
end
