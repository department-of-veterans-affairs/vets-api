# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require 'support/stub_efolder_documents'
require_relative '../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Efolder', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  describe 'GET /v0/efolder/documents' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      stub_efolder_index_documents

      let!(:efolder_response) do
        { 'data' => [{ 'id' => '{73CD7B28-F695-4337-BBC1-2443A913ACF6}', 'type' => 'efolder_document',
                       'attributes' => { 'docType' => '702',
                                         'typeDescription' =>
                                           'Disability Benefits Questionnaire (DBQ) - Veteran Provided',
                                         'receivedAt' => '2024-09-13' } },
                     { 'id' => '{EF7BF420-7E49-4FA9-B14C-CE5F6225F615}', 'type' => 'efolder_document',
                       'attributes' => { 'docType' => '45',
                                         'typeDescription' => 'Military Personnel Record',
                                         'receivedAt' => '2024-09-13' } }] }
      end

      it 'and a result that matches our schema is successfully returned with the 200 status' do
        get '/mobile/v0/efolder/documents', headers: sis_headers
        assert_schema_conform(200)
        expect(response.parsed_body).to eq(efolder_response)
      end
    end

    context 'with an error from upstream' do
      before do
        efolder_service = double
        expect(Efolder::Service).to receive(:new).and_return(efolder_service)
        expect(efolder_service).to receive(:list_documents).and_raise(Common::Exceptions::BackendServiceException)
      end

      it 'returns expected error' do
        get '/mobile/v0/efolder/documents', headers: sis_headers

        assert_schema_conform(400)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Operation failed',
                                                            'detail' => 'Operation failed',
                                                            'code' => 'VA900', 'status' => '400' }] })
      end
    end
  end

  describe 'GET /v0/efolder/documents/:document_id/download' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      stub_efolder_show_document
      it 'returns expected document' do
        post "/mobile/v0/efolder/documents/#{CGI.escape(document_id)}/download", params: { file_name: 'test' },
                                                                                 headers: sis_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(content)
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=\"test\"; filename*=UTF-8''test")
        expect(response.headers['Content-Type']).to eq('application/pdf')
      end
    end

    context 'with an error from upstream' do
      before do
        efolder_service = double
        expect(Efolder::Service).to receive(:new).and_return(efolder_service)
        expect(efolder_service).to receive(:get_document).and_raise(Common::Exceptions::BackendServiceException)
      end

      it 'returns expected error' do
        post '/mobile/v0/efolder/documents/123/download', params: { file_name: 'test' }, headers: sis_headers

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Operation failed',
                                                            'detail' => 'Operation failed',
                                                            'code' => 'VA900', 'status' => '400' }] })
      end
    end
  end
end
