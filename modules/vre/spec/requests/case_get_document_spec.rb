# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::CaseGetDocument', type: :request do
  before { sign_in_as(user) }

  describe 'POST vre/v0/case_get_document' do
    let(:valid_request_body) do
      {
        resCaseId: 4574,
        documentType: '626'
      }
    end

    context 'when document is returned' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 200 with pdf bytes' do
        VCR.use_cassette('vre/case_get_document/200') do
          post '/vre/v0/case_get_document', params: valid_request_body
          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to include('application/pdf')
          expect(response.body).to include('%PDF')
        end
      end
    end

    context 'when document not found' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 404 with standard error envelope' do
        VCR.use_cassette('vre/case_get_document/404') do
          post '/vre/v0/case_get_document', params: valid_request_body
          expect(response).to have_http_status(:not_found)
          body = JSON.parse(response.body)
          expect(body['errors']).to be_present
          expect(body['errors'].first['detail']).to eq('Not Found')
          expect(body['errors'].first['code']).to eq('RES_CASE_GET_DOCUMENT_404')
        end
      end
    end

    context 'when invalid caseId is sent' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 403 with standard error envelope' do
        VCR.use_cassette('vre/case_get_document/403') do
          post '/vre/v0/case_get_document', params: valid_request_body.merge(resCaseId: 999_999)
          expect(response).to have_http_status(:forbidden)
          body = JSON.parse(response.body)
          expect(body['errors']).to be_present
          expect(body['errors'].first['detail']).to eq('Forbidden')
          expect(body['errors'].first['code']).to eq('RES_CASE_GET_DOCUMENT_403')
        end
      end
    end

    context 'when request is invalid' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 400 with standard error envelope' do
        post '/vre/v0/case_get_document', params: valid_request_body.merge(documentType: '')
        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'].first['detail']).to eq('The required parameter "documentType", is missing')
      end
    end

    context 'when upstream server error' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 500 with standard error envelope' do
        VCR.use_cassette('vre/case_get_document/500') do
          post '/vre/v0/case_get_document', params: valid_request_body
          expect(response).to have_http_status(:internal_server_error)
          body = JSON.parse(response.body)
          expect(body['errors']).to be_present
          expect(body['errors'].first['detail']).to eq('Internal Server Error')
        end
      end
    end

    context 'when missing required params' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 400 when resCaseId missing' do
        post '/vre/v0/case_get_document', params: valid_request_body.except(:resCaseId)
        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail']).to eq('The required parameter "resCaseId", is missing')
      end

      it 'returns 400 when documentType missing' do
        post '/vre/v0/case_get_document', params: valid_request_body.except(:documentType)
        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail']).to eq('The required parameter "documentType", is missing')
      end

      it 'returns 400 when both required params are missing' do
        post '/vre/v0/case_get_document', params: {}
        expect(response).to have_http_status(:bad_request)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail']).to eq('The required parameter "resCaseId", is missing')
      end
    end
  end
end
