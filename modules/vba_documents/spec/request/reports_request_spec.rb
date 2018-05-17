# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VBA Document Uploads Report Endpoint', type: :request do
  describe '#create /v0/uploads/report' do
    let(:upload) { FactoryBot.create(:upload_submission) }
    let(:upload_received) { FactoryBot.create(:upload_submission, status: 'received') }
    let(:upload2_received) { FactoryBot.create(:upload_submission, guid: SecureRandom.uuid, status: 'received') }
    let(:client_stub) { instance_double('PensionBurial::Service') }
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
      before(:each) do
        expect(PensionBurial::Service).to receive(:new) { client_stub }
        expect(client_stub).to receive(:status).and_return(faraday_response)
      end

      it 'should return status of a single upload submissions' do
        expect(faraday_response).to receive(:success?).and_return(true)
        received_element[0]['uuid'] = upload_received.guid
        expect(faraday_response).to receive(:body).at_least(:once).and_return([received_element].to_json)
        params = [upload_received.guid]
        post '/services/vba_documents/v0/uploads/report', ids: params
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
      end

      it 'should return status of a multiple upload submissions' do
        expect(faraday_response).to receive(:success?).and_return(true)
        received_element[0]['uuid'] = upload_received.guid
        processing_element[0]['uuid'] = upload2_received.guid
        body = [received_element, processing_element].to_json
        expect(faraday_response).to receive(:body).at_least(:once).and_return(body)
        params = [upload_received.guid, upload2_received.guid]
        post '/services/vba_documents/v0/uploads/report', ids: params
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(2)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
        expect(ids).to include(upload2_received.guid)
      end

      it 'should silently skip status not returned from central mail' do
        expect(faraday_response).to receive(:success?).and_return(true)
        received_element[0]['uuid'] = upload_received.guid
        processing_element[0]['uuid'] = upload2_received.guid
        expect(faraday_response).to receive(:body).at_least(:once).and_return([received_element, []].to_json)
        params = [upload_received.guid, upload2_received.guid]
        post '/services/vba_documents/v0/uploads/report', ids: params
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(2)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload_received.guid)
        expect(ids).to include(upload2_received.guid)
      end

      it 'should raise an error if gateway unavailable' do
        expect(faraday_response).to receive(:success?).and_return(false)
        expect(faraday_response).to receive(:status).and_return(401)
        expect(faraday_response).to receive(:body).at_least(:once).and_return('Unauthorized')
        params = [upload_received.guid, upload2_received.guid]
        post '/services/vba_documents/v0/uploads/report', ids: params
        expect(response).to have_http_status(:bad_gateway)
      end
    end

    context 'without in-flight submissions' do
      before(:each) do
        expect(PensionBurial::Service).not_to receive(:new) { client_stub }
      end

      it 'should not fetch status if no in-flight submissions' do
        params = [upload.guid]
        post '/services/vba_documents/v0/uploads/report', ids: params
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].size).to eq(1)
        ids = json['data'].map { |x| x['attributes']['guid'] }
        expect(ids).to include(upload.guid)
      end

      it 'should omit results for non-existent submission' do
        post '/services/vba_documents/v0/uploads/report', ids: ['fake-1234']
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data']).to be_empty
      end
    end

    context 'with invalid parameters' do
      it 'should return error if no guids parameter' do
        post '/services/vba_documents/v0/uploads/report', foo: 'bar'
        expect(response).to have_http_status(:bad_request)
      end

      it 'should return error if guids parameter not a list' do
        post '/services/vba_documents/v0/uploads/report', ids: 'bar'
        expect(response).to have_http_status(:bad_request)
      end

      it 'should return error if guids parameter has too many elements' do
        params = Array.new(101, 'abcd-1234')
        post '/services/vba_documents/v0/uploads/report', ids: params
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
