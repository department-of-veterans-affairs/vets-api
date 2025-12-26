# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require 'support/stub_efolder_documents'
require_relative '../../../support/helpers/committee_helper'
require 'lighthouse/benefits_documents/service'

RSpec.describe 'Mobile::V0::Efolder', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  describe 'GET /v0/efolder/documents' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      before do
        allow(Flipper).to receive(:enabled?).with(:efolder_use_lighthouse_benefits_documents_service,
                                                  instance_of(User)).and_return(false)
      end

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

        allow(Flipper).to receive(:enabled?).with(:efolder_use_lighthouse_benefits_documents_service,
                                                  instance_of(User)).and_return(false)
      end

      it 'returns expected error' do
        get '/mobile/v0/efolder/documents', headers: sis_headers

        assert_schema_conform(400)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Operation failed',
                                                            'detail' => 'Operation failed',
                                                            'code' => 'VA900', 'status' => '400' }] })
      end
    end

    context 'when :efolder_use_lighthouse_benefits_documents_service is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:efolder_use_lighthouse_benefits_documents_service,
                                                  instance_of(User)).and_return(true)
      end

      context 'with working upstream service' do
        response_body1 = {
          data: {
            documents: [
              {
                docTypeId: 137,
                subject: 'File contains evidence related to the claim',
                documentUuid: '{12345678-ABCD-0123-cdef-124345679ABC}',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension 1',
                uploadedDateTime: '2016-02-04T17:51:56Z',
                receivedAt: '2016-02-04'
              },
              {
                docTypeId: 137,
                subject: 'File contains evidence related to the claim',
                documentUuid: '{12345678-ABCD-0123-cdef-124345679ABD}',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension 2',
                uploadedDateTime: '2016-02-04T17:51:56Z',
                receivedAt: '2016-02-04'
              }
            ]
          },
          pagination: {
            pageNumber: 1,
            pageSize: 2
          }
        }

        response_body2 = {
          data: {
            documents: [
              {
                docTypeId: 137,
                subject: 'File contains evidence related to the claim',
                documentUuid: '{12345678-ABCD-0123-cdef-124345679ABE}',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension 3',
                uploadedDateTime: '2016-02-04T17:51:56Z',
                receivedAt: '2016-02-04'
              },
              {
                docTypeId: 137,
                subject: 'File contains evidence related to the claim',
                documentUuid: '{12345678-ABCD-0123-cdef-124345679ABF}',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension 4',
                uploadedDateTime: '2016-02-04T17:51:56Z',
                receivedAt: '2016-02-04'
              }
            ]
          },
          pagination: {
            pageNumber: 2,
            pageSize: 2
          }
        }

        response_body3 = {
          data: {
            documents: [
              {
                docTypeId: 137,
                subject: 'File contains evidence related to the claim',
                documentUuid: '{12345678-ABCD-0123-cdef-124345679ABG}',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension 5',
                uploadedDateTime: '2016-02-04T17:51:56Z',
                receivedAt: '2016-02-04'
              }
            ]
          },
          pagination: {
            pageNumber: 3,
            pageSize: 2
          }
        }

        before do
          benefits_document_service_double = double
          expect(BenefitsDocuments::Service).to receive(:new).and_return(benefits_document_service_double)
          expect(benefits_document_service_double).to receive(:participant_documents_search).and_return(
            Faraday::Response.new(
              status: 200, body: response_body1.as_json
            ),
            Faraday::Response.new(
              status: 200, body: response_body2.as_json
            ),
            Faraday::Response.new(
              status: 200, body: response_body3.as_json
            )
          )
        end

        it 'returns expected documents from Benefits Documents Service' do
          # resize max page size for testing purposes
          stub_const('Mobile::V0::EfolderController::MAX_PAGE_SIZE', 2)

          get '/mobile/v0/efolder/documents', headers: sis_headers

          assert_schema_conform(200)
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body['data'].size).to eq(5)
          expect(response.parsed_body['data'].first['id']).to eq('{12345678-ABCD-0123-cdef-124345679ABC}')
          expect(response.parsed_body['data'].first['attributes']['docType']).to eq('137')
          expect(response.parsed_body['data'].first['attributes']['typeDescription']).to eq(
            'VA 21-526 Veterans Application for Compensation or Pension 1'
          )
          expect(response.parsed_body['data'].first['attributes']['receivedAt']).to eq('2016-02-04')
          expect(response.parsed_body['data'].last['id']).to eq('{12345678-ABCD-0123-cdef-124345679ABG}')
          expect(response.parsed_body['data'].last['attributes']['typeDescription']).to eq(
            'VA 21-526 Veterans Application for Compensation or Pension 5'
          )
        end
      end

      context 'with an error from upstream' do
        let(:bad_request_error) do
          Faraday::BadRequestError.new(
            status: 400,
            headers: {
              'content-type' => 'application/json'
            },
            body: {
              'errors' => [{
                'status' => 400,
                'title' => 'Invalid field value',
                'detail' => 'Code must match \"^[A-Z]{2}$\"'
              }]
            }
          )
        end

        before do
          allow_any_instance_of(BenefitsDocuments::Configuration)
            .to receive(:participant_documents_search).and_raise(bad_request_error)
        end

        it 'returns expected error' do
          get '/mobile/v0/efolder/documents', headers: sis_headers

          assert_schema_conform(400)
          expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Invalid field value',
                                                              'detail' => 'Code must match \"^[A-Z]{2}$\"',
                                                              'code' => '400',
                                                              'status' => '400' }] })
        end
      end
    end
  end

  describe 'GET /v0/efolder/documents/:document_id/download' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      before do
        allow(Flipper).to receive(:enabled?).with(:efolder_use_lighthouse_benefits_documents_service,
                                                  instance_of(User)).and_return(false)
      end

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

        allow(Flipper).to receive(:enabled?).with(:efolder_use_lighthouse_benefits_documents_service,
                                                  instance_of(User)).and_return(false)
      end

      it 'returns expected error' do
        post '/mobile/v0/efolder/documents/123/download', params: { file_name: 'test' }, headers: sis_headers

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Operation failed',
                                                            'detail' => 'Operation failed',
                                                            'code' => 'VA900', 'status' => '400' }] })
      end
    end

    context 'when :efolder_use_lighthouse_benefits_documents_service is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:efolder_use_lighthouse_benefits_documents_service,
                                                  instance_of(User)).and_return(true)
      end

      context 'with a working upstream service' do
        let(:document_uuid) { '93631483-E9F9-44AA-BB55-3552376400D8' }
        let(:content) { File.read('spec/fixtures/files/tiny.pdf') }

        before do
          benefits_document_service_double = double
          expect(BenefitsDocuments::Service).to receive(:new).and_return(benefits_document_service_double)
          expect(benefits_document_service_double)
            .to receive(:participant_documents_download).with(
              document_uuid:,
              participant_id: user.participant_id
            ).and_return(
              Faraday::Response.new(
                status: 200, body: content
              )
            )
        end

        it 'returns expected document' do
          post "/mobile/v0/efolder/documents/#{CGI.escape("{#{document_uuid}}")}/download",
               params: { file_name: 'test' },
               headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(content)
          expect(response.headers['Content-Disposition']).to eq("attachment; filename=\"test\"; filename*=UTF-8''test")
          expect(response.headers['Content-Type']).to eq('application/pdf')
        end
      end

      context 'with an error from upstream' do
        let(:bad_request_error) do
          Faraday::BadRequestError.new(
            status: 400,
            headers: {
              'content-type' => 'application/json'
            },
            body: {
              'errors' => [{
                'status' => 400,
                'title' => 'Invalid field value',
                'detail' => 'Code must match \"^[A-Z]{2}$\"'
              }]
            }
          )
        end

        before do
          allow_any_instance_of(BenefitsDocuments::Configuration)
            .to receive(:participant_documents_download).and_raise(bad_request_error)
        end

        it 'returns expected error' do
          post '/mobile/v0/efolder/documents/123/download', params: { file_name: 'test' }, headers: sis_headers

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Invalid field value',
                                                              'detail' => 'Code must match \"^[A-Z]{2}$\"',
                                                              'code' => '400',
                                                              'status' => '400' }] })
        end
      end
    end
  end
end
