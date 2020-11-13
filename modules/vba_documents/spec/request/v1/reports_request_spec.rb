# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/vba_document_fixtures'
require 'vba_documents/pdf_inspector'
require_relative '../../../app/serializers/vba_documents/upload_serializer'

RSpec.describe 'VBA Document Uploads Report Endpoint', type: :request do
  describe '#create /v1/uploads/report' do
    let(:upload) { FactoryBot.create(:upload_submission) }
    let(:pdf_info) { FactoryBot.create(:upload_submission, :status_uploaded, consumer_name: 'test consumer') }
    let(:upload_received) { FactoryBot.create(:upload_submission, status: 'received') }
    let(:upload2_received) { FactoryBot.create(:upload_submission, guid: SecureRandom.uuid, status: 'received') }

    context 'with in-flight submissions' do
      it 'returns status of a single upload submissions' do
        params = [upload_received.guid]
        post '/services/vba_documents/v1/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
      end

      it 'returns status of a multiple upload submissions' do
        params = [upload_received.guid, upload2_received.guid]
        post '/services/vba_documents/v1/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(2)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
        expect(ids).to include(upload2_received.guid)
      end

      it 'silentlies skip status not returned from central mail' do
        params = [upload_received.guid, upload2_received.guid]
        post '/services/vba_documents/v1/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(2)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
        expect(ids).to include(upload2_received.guid)
      end
    end

    context 'without in-flight submissions' do
      it 'does not fetch status if no in-flight submissions' do
        params = [upload.guid]
        post '/services/vba_documents/v1/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload.guid)
      end

      it 'presents error result for non-existent submission' do
        post '/services/vba_documents/v1/uploads/report', params: { ids: ['fake-1234'] }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        status = json['data'][0]
        expect(status['id']).to eq('fake-1234')
        expect(status['attributes']['guid']).to eq('fake-1234')
        expect(status['attributes']['code']).to eq('DOC105')
      end
    end

    context 'with invalid parameters' do
      it 'returns error if no guids parameter' do
        post '/services/vba_documents/v1/uploads/report', params: { foo: 'bar' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error if guids parameter not a list' do
        post '/services/vba_documents/v1/uploads/report', params: { ids: 'bar' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error if guids parameter has too many elements' do
        params = Array.new(1001, 'abcd-1234')
        post '/services/vba_documents/v1/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with uploaded pdf data' do
      it 'reports on pdf upload data' do
        params = [pdf_info.guid]
        post '/services/vba_documents/v1/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data'].size).to eq(1)
        valid_doc = 'modules/vba_documents/spec/fixtures/valid_multipart_pdf_attachments.blob'
        inspector = VBADocuments::PDFInspector.new(pdf: valid_doc, add_file_key: false)
        pdf_controller_data = json['data'].first['attributes']['uploaded_pdf']
        pdf_data = VBADocuments::UploadSerializer.scrub_unnecessary_keys(inspector.pdf_data.as_json)
        expect(pdf_controller_data.eql?(pdf_data)).to eq(true)
      end
    end
  end
end
