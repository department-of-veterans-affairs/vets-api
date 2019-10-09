# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VBA Document Uploads Report Endpoint', type: :request do
  describe '#create /v0/uploads/report' do
    let(:upload) { FactoryBot.create(:upload_submission) }
    let(:upload_received) { FactoryBot.create(:upload_submission, status: 'received') }
    let(:upload2_received) { FactoryBot.create(:upload_submission, guid: SecureRandom.uuid, status: 'received') }
    let(:client_stub) { instance_double('CentralMail::Service') }
    let(:faraday_response) { instance_double('Faraday::Response') }

    let(:received_element) do
      [{ "uuid": 'ignored',
         "status": 'Received',
         "errorMessage": '',
         "lastUpdated": '2018-04-25 00:02:39' }]
    end
    let(:processing_element) do
      [{ "uuid": 'ignored',
         "status": 'In Process',
         "errorMessage": '',
         "lastUpdated": '2018-04-25 00:02:39' }]
    end
    let(:success_element) do
      [{ "uuid": 'ignored',
         "status": 'Success',
         "errorMessage": '',
         "lastUpdated": '2018-04-25 00:02:39' }]
    end

    context 'with in-flight submissions' do
      it 'returns status of a single upload submissions' do
        params = [upload_received.guid]
        post '/services/vba_documents/v0/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
      end

      it 'returns status of a multiple upload submissions' do
        params = [upload_received.guid, upload2_received.guid]
        post '/services/vba_documents/v0/uploads/report', params: { ids: params }
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
        post '/services/vba_documents/v0/uploads/report', params: { ids: params }
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
      before do
        expect(CentralMail::Service).not_to receive(:new) { client_stub }
      end

      it 'does not fetch status if no in-flight submissions' do
        params = [upload.guid]
        post '/services/vba_documents/v0/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload.guid)
      end

      it 'presents error result for non-existent submission' do
        post '/services/vba_documents/v0/uploads/report', params: { ids: ['fake-1234'] }
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
        post '/services/vba_documents/v0/uploads/report', params: { foo: 'bar' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error if guids parameter not a list' do
        post '/services/vba_documents/v0/uploads/report', params: { ids: 'bar' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error if guids parameter has too many elements' do
        params = Array.new(1001, 'abcd-1234')
        post '/services/vba_documents/v0/uploads/report', params: { ids: params }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
