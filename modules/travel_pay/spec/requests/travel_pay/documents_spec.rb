# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::V0::DocumentsController, type: :request do
  include TravelPay::Engine.routes.url_helpers

  let(:claim_id) { '73611905-71bf-46ed-b1ec-e790593b8565' }
  let(:doc_id) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:user) { build(:user) }
  let(:service) { instance_double(TravelPay::DocumentsService) }
  let(:valid_document) do
    Rack::Test::UploadedFile.new('modules/travel_pay/spec/fixtures/documents/test.pdf')
  end

  before do
    allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize).and_return({ veis_token: 'veis_token',
                                                                                      btsss_token: 'btsss_token' })
    sign_in(user)
  end

  # GET /travel_pay/v0/claims/:claim_id/documents/:id
  describe 'show' do
    headers = { 'Authorization' => 'Bearer vagov_token' }
    filename = 'AppealForm.pdf'

    context 'when the document is successfully retrieved' do
      it 'returns the document data with correct headers' do
        VCR.use_cassette('travel_pay/documents/get/success_pdf', match_requests_on: %i[method path]) do
          get(doc_path, headers:)

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to be_empty
          expect(response.headers['Content-Type']).to eq('application/pdf')
          expect(response.headers['Content-Disposition']).to include(filename)
          expect(response.headers['Content-Length']).to be_present
        end
      end
    end

    context 'when the document is not found' do
      it 'returns a 404 error with a proper message' do
        VCR.use_cassette('travel_pay/documents/get/not_found', match_requests_on: %i[method path]) do
          get(doc_path('bad-id'), headers:)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when an unhandled error occurs' do
      it 'logs the error and raises exception' do
        VCR.use_cassette('travel_pay/documents/get/internal_error', match_requests_on: %i[method path]) do
          expect(Rails.logger).to receive(:error).with(/^Error downloading document:.*/)

          get(doc_path('big-bad-error'), headers:)

          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end

  # DELETE /travel_pay/v0/claims/:claim_id/documents/:id
  describe 'destroy' do
    before do
      allow_any_instance_of(TravelPay::V0::DocumentsController).to receive(:current_user).and_return(user)
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
      end

      context 'vcr tests' do
        context 'when the document is successfully deleted' do
          it 'returns the document data with correct headers' do
            VCR.use_cassette('travel_pay/documents/delete/success', match_requests_on: %i[method path]) do
              delete(doc_path)

              expect(response).to have_http_status(:ok)
              body = JSON.parse(response.body)

              expect(body['documentId']).to eq('123e4567-e89b-12d3-a456-426614174000')
            end
          end
        end
      end

      context 'stubbed service behavior' do
        before do
          allow_any_instance_of(TravelPay::V0::DocumentsController)
            .to receive(:service).and_return(service)
        end

        it 'deletes document and returns documentId' do
          allow(service).to receive(:delete_document)
            .with(claim_id, doc_id)
            .and_return({ 'documentId' => '123e4567-e89b-12d3-a456-426614174000' })

          delete(doc_path)

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq('documentId' => '123e4567-e89b-12d3-a456-426614174000')
        end

        it 'returns bad request when claim_id is invalid' do
          invalid_claim_id = 'invalid$'

          delete("/travel_pay/v0/claims/#{invalid_claim_id}/documents/123e4567-e89b-12d3-a456-426614174000")

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['errors'].first['detail']).to eq('Claim ID is invalid')
        end

        it 'returns bad request when document_id is invalid' do
          invalid_doc_id = 'bad!!'

          delete("/travel_pay/v0/claims/#{claim_id}/documents/#{invalid_doc_id}")

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['errors'].first['detail']).to eq('Document ID is invalid')
        end

        it 'returns not found when Faraday::ResourceNotFound' do
          exception = Faraday::ResourceNotFound.new('Not found')
          allow(exception).to receive(:response).and_return(
            request: { headers: { 'X-Correlation-ID' => 'abc' } }
          )
          allow(service).to receive(:delete_document).and_raise(exception)

          delete(doc_path)

          expect(response).to have_http_status(:not_found)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('Document not found')
          expect(body['correlation_id']).to eq('abc')
        end

        it 'returns client error JSON when Faraday::ClientError' do
          error = Faraday::ClientError.new('Bad request')
          allow(error).to receive(:response).and_return({ status: 400, body: 'invalid document' })
          allow(service).to receive(:delete_document).and_raise(error)

          delete(doc_path)

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail']).to eq('invalid document')
        end

        it 'returns server error JSON when Faraday::ServerError' do
          error = Faraday::ServerError.new('Internal server error')
          allow(error).to receive(:response).and_return({ status: 500 })
          allow(service).to receive(:delete_document).and_raise(error)

          delete(doc_path)

          expect(response).to have_http_status(:internal_server_error)
          expect(JSON.parse(response.body)['errors'].first['detail']).to eq('Server error deleting document')
        end
      end
    end
  end

  # POST /travel_pay/v0/claims/:claim_id/documents
  describe '#create' do
    before do
      allow_any_instance_of(TravelPay::V0::DocumentsController).to receive(:current_user).and_return(user)
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_enable_complex_claims, instance_of(User)).and_return(true)
      end

      context 'stubbed service behavior' do
        before do
          allow(service).to receive(:upload_document)
            .with(claim_id, kind_of(ActionDispatch::Http::UploadedFile))
            .and_return({ 'documentId' => 'abc-123' })
          allow_any_instance_of(TravelPay::V0::DocumentsController)
            .to receive(:service).and_return(service)
        end

        it 'uploads document and returns documentId' do
          post("/travel_pay/v0/claims/#{claim_id}/documents", params: { Document: valid_document })

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)).to eq('documentId' => 'abc-123')
        end

        it 'returns bad request when document param is missing' do
          post("/travel_pay/v0/claims/#{claim_id}/documents", params: {})

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['errors'].first['detail']).to eq('Document is required')
        end

        # NOTE: In request specs, you can’t make params[:claim_id] truly missing because
        # it’s part of the URL path and Rails routing prevents that.
        it 'returns bad request when claim_id is invalid' do
          invalid_claim_id = 'invalid$' # safe in URL, fails regex \A[\w-]+\z

          post("/travel_pay/v0/claims/#{invalid_claim_id}/documents", params: { Document: valid_document })

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['errors'].first['detail']).to eq('Claim ID is invalid')
        end

        it 'returns not found when Faraday::ResourceNotFound' do
          exception = Faraday::ResourceNotFound.new('Not found')
          allow(exception).to receive(:response).and_return(
            request: { headers: { 'X-Correlation-ID' => 'abc' } }
          )
          allow(service).to receive(:upload_document).and_raise(exception)

          post("/travel_pay/v0/claims/#{claim_id}/documents", params: { Document: valid_document })

          expect(response).to have_http_status(:not_found)
          expect(JSON.parse(response.body)['error']).to eq('Document not found')
          expect(JSON.parse(response.body)['correlation_id']).to eq('abc')
        end

        it 'returns error json with status when Faraday::Error' do
          error = Faraday::Error.new('ERROR')
          allow(error).to receive(:response).and_return({ status: 502 }) # 502 = bad_gateway error
          allow(service).to receive(:upload_document).and_raise(error)

          post("/travel_pay/v0/claims/#{claim_id}/documents", params: { Document: valid_document })

          expect(response).to have_http_status(:bad_gateway)
          expect(JSON.parse(response.body)['error']).to eq('Error uploading document')
        end
      end
    end

    context 'when feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:travel_pay_enable_complex_claims, instance_of(User))
          .and_return(false)
      end

      it 'returns 503 Service Unavailable' do
        post("/travel_pay/v0/claims/#{claim_id}/documents", params: { Document: valid_document })

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        expect(body['errors'].first['detail']).to include('Travel Pay document endpoint unavailable per feature toggle')
      end
    end
  end

  describe 'endpoint version routing' do
    context 'show (get_document_binary)' do
      let(:headers) { { 'Authorization' => 'Bearer vagov_token' } }

      context 'when travel_pay_claims_api_v3_upgrade is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:travel_pay_claims_api_v3_upgrade)
            .and_return(true)
        end

        it 'uses v3 endpoint for get_document_binary' do
          VCR.use_cassette('travel_pay/documents_v3/get_binary_success', match_requests_on: %i[method path]) do
            get(doc_path, headers:)

            expect(response).to have_http_status(:ok)
            expect(response.body).not_to be_empty
            expect(response.headers['Content-Type']).to eq('application/pdf')
          end
        end
      end

      context 'when travel_pay_claims_api_v3_upgrade is disabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:travel_pay_claims_api_v3_upgrade)
            .and_return(false)
        end

        it 'uses v2 endpoint for get_document_binary' do
          VCR.use_cassette('travel_pay/documents/get/success_pdf', match_requests_on: %i[method path]) do
            get(doc_path, headers:)

            expect(response).to have_http_status(:ok)
            expect(response.body).not_to be_empty
            expect(response.headers['Content-Type']).to eq('application/pdf')
          end
        end
      end
    end
  end

  def doc_path(doc_id = nil)
    "/travel_pay/v0/claims/#{claim_id}/documents/#{doc_id || '123e4567-e89b-12d3-a456-426614174000'}"
  end
end
