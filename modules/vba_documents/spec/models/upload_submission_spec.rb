# frozen_string_literal: true

require 'rails_helper'

describe VBADocuments::UploadSubmission, type: :model do
  let(:upload_pending) { FactoryBot.create(:upload_submission) }
  let(:upload_uploaded) { FactoryBot.create(:upload_submission, status: 'uploaded') }
  let(:upload_received) { FactoryBot.create(:upload_submission, status: 'received') }
  let(:upload_processing) { FactoryBot.create(:upload_submission, status: 'processing') }
  let(:upload_success) { FactoryBot.create(:upload_submission, status: 'success') }
  let(:upload_vbms) { FactoryBot.create(:upload_submission, status: 'vbms') }
  let(:upload_error) { FactoryBot.create(:upload_submission, status: 'error') }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }

  let(:received_body) do
    [[{ "uuid": 'ignored',
        "status": 'Received',
        "errorMessage": '',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:processing_body) do
    [[{ "uuid": 'ignored',
        "status": 'In Process',
        "errorMessage": '',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:success_body) do
    [[{ "uuid": 'ignored',
        "status": 'Success',
        "errorMessage": '',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:processing_success_body) do
    [[{ "uuid": 'ignored',
        "status": 'Processing Success',
        "errorMessage": '',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:error_body) do
    [[{ "uuid": 'ignored',
        "status": 'Error',
        "errorMessage": 'Invalid splines',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:processing_error_body) do
    [[{ "uuid": 'ignored',
        "status": 'Processing Error',
        "errorMessage": 'Invalid splines',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:nonsense_body) do
    [[{ "uuid": 'ignored',
        "status": 'Whowhatnow?',
        "errorMessage": '',
        "lastUpdated": '2018-04-25 00:02:39' }]].to_json
  end
  let(:empty_body) do
    [[]].to_json
  end

  before do
    allow(CentralMail::Service).to receive(:new) { client_stub }
  end

  describe 'consumer_name' do
    it 'returns unknown when no name is set' do
      upload = FactoryBot.create(:upload_submission, consumer_name: nil)
      expect(upload.consumer_name).to eq('unknown')
    end

    it 'returns name when set' do
      upload = FactoryBot.create(:upload_submission, consumer_name: 'test consumer')
      expect(upload.consumer_name).to eq('test consumer')
    end
  end

  describe 'refresh_status!' do
    it 'updates received status from downstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(received_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'updates processing status from downstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(processing_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('processing')
    end

    it 'updates processing success status from downstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(processing_success_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('processing')
    end

    it 'updates success status from downstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(success_body)
      upload_processing.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_processing.guid)
      expect(updated.status).to eq('success')
    end

    it 'updates error status from downstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(processing_error_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC202')
      expect(updated.detail).to include('Invalid splines')
    end

    it 'updates processing error status from downstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(error_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC202')
      expect(updated.detail).to include('Invalid splines')
    end

    it 'skips downstream status check if not yet submitted' do
      expect(client_stub).not_to receive(:status)
      upload_pending.refresh_status!
    end

    it 'skips downstream status check if already in error state' do
      expect(client_stub).not_to receive(:status)
      upload_error.refresh_status!
    end

    it 'skips downstream status check if already in vbms state' do
      expect(client_stub).not_to receive(:status)
      upload_vbms.refresh_status!
    end

    it 'raises on error status from downstream without updating state' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(false)
      expect(faraday_response).to receive(:status).and_return(401)
      expect(faraday_response).to receive(:body).at_least(:once).and_return('Unauthorized')
      expect { upload_received.refresh_status! }.to raise_error(Common::Exceptions::BadGateway)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'raises on duplicate error status from downstream and updates state' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(false)
      expect(faraday_response).to receive(:status).and_return(401)
      expect(faraday_response).to receive(:body).at_least(:once).and_return('Document already uploaded with uuid')
      expect { upload_received.refresh_status! }.to raise_error(Common::Exceptions::BadGateway)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'raises on unexpected status from downstream without updating state' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(nonsense_body)
      expect { upload_received.refresh_status! }.to raise_error(Common::Exceptions::BadGateway)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'ignores empty status from downstream for known uuid' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(empty_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'reports an error to Statsd when changed to error' do
      expect(StatsD).to receive(:increment)
      upload_processing.status = 'error'
      upload_processing.save
    end
  end
end
