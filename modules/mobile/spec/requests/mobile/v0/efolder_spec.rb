# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require 'support/stub_efolder_documents'

RSpec.describe 'Mobile::V0::Efolder', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/efolder/documents' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      stub_efolder_documents(:index)

      let!(:efolder_response) do
        { 'data' => [{ 'id' => '{93631483-E9F9-44AA-BB55-3552376400D8}', 'type' => 'efolder_document',
                       'attributes' => { 'docType' => '1215',
                                         'typeDescription' => 'DMC - Debt Increase Letter',
                                         'receivedAt' => '2020-05-28' } }] }
      end

      it 'and a result that matches our schema is successfully returned with the 200 status' do
        get '/mobile/v0/efolder/documents', headers: sis_headers
        expect(response).to have_http_status(:ok)
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

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Operation failed',
                                                            'detail' => 'Operation failed',
                                                            'code' => 'VA900', 'status' => '400' }] })
      end
    end
  end

  describe 'GET /v0/efolder/documents/:document_id/download' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      stub_efolder_documents(:show)
      it 'returns expected document' do
        get "/mobile/v0/efolder/documents/#{CGI.escape(document_id)}/download", params: { file_name: 'test' },
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
        get '/mobile/v0/efolder/documents/123/download', params: { file_name: 'test' }, headers: sis_headers

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Operation failed',
                                                            'detail' => 'Operation failed',
                                                            'code' => 'VA900', 'status' => '400' }] })
      end
    end
  end
end
