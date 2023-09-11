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
    [[{ uuid: 'ignored',
        status: 'Received',
        errorMessage: '',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:processing_body) do
    [[{ uuid: 'ignored',
        status: 'In Process',
        errorMessage: '',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:success_body) do
    [[{ uuid: 'ignored',
        status: 'Success',
        errorMessage: '',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:processing_success_body) do
    [[{ uuid: 'ignored',
        status: 'Processing Success',
        errorMessage: '',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:error_body) do
    [[{ uuid: 'ignored',
        status: 'Error',
        errorMessage: 'Invalid splines',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:processing_error_body) do
    [[{ uuid: 'ignored',
        status: 'Processing Error',
        errorMessage: 'Invalid splines',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:nonsense_body) do
    [[{ uuid: 'ignored',
        status: 'Whowhatnow?',
        errorMessage: '',
        lastUpdated: '2018-04-25 00:02:39' }]].to_json
  end
  let(:empty_body) do
    [[]].to_json
  end

  before do
    allow(CentralMail::Service).to receive(:new) { client_stub }
  end

  def status_complete_packets(*reasons)
    ret = [[{
      uuid: 'ignored',
      status: 'Complete',
      errorMessage: '',
      lastUpdated: '2018-04-25 00:02:39',
      packets: []
    }]]
    reasons.each do |r|
      packet = {
        veteranId: '777889999',
        status: 'Complete',
        completedReason: r,
        transactionDate: '2018-04-25 00:02:39'
      }

      ret[0][0][:packets] << packet
    end
    ret.to_json
  end

  describe '.in_flight' do
    subject { described_class.in_flight }

    let(:all_statuses) { described_class::ALL_STATUSES }
    let(:in_flight_statuses) { described_class::IN_FLIGHT_STATUSES }
    let(:final_success_key) { described_class::FINAL_SUCCESS_STATUS_KEY }
    let(:vbms_deployment_date) { described_class::VBMS_STATUS_DEPLOYMENT_DATE }

    it "returns records that have a status defined in 'IN_FLIGHT_STATUSES'" do
      all_statuses.each do |status|
        upload = FactoryBot.create(:upload_submission, status:, guid: SecureRandom.uuid)

        if in_flight_statuses.include?(status)
          expect(subject).to include(upload)
        else
          expect(subject).not_to include(upload)
        end
      end
    end

    it "returns records that do not have a 'final success' status key" do
      upload = FactoryBot.create(:upload_submission, status: 'success')
      expect(subject).to include(upload)
    end

    it "does not return records that have a 'final success' status key" do
      upload = FactoryBot.create(:upload_submission, :status_final_success)
      expect(subject).not_to include(upload)
    end

    it 'returns records created after the VBMS status deployment date' do
      upload = FactoryBot.create(:upload_submission, status: 'success', created_at: vbms_deployment_date.next_day(1))
      expect(subject).to include(upload)
    end

    it 'does not return records created before the VBMS status deployment date' do
      upload = FactoryBot.create(:upload_submission, status: 'success', created_at: vbms_deployment_date.prev_day(1))
      expect(subject).not_to include(upload)
    end
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
    it 'updates received status from upstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(received_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'updates processing status from upstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(processing_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('processing')
    end

    it 'updates processing success status from upstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(processing_success_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('processing')
    end

    it 'updates completed status from upstream to VBMS' do
      resp = status_complete_packets(VBADocuments::UploadSubmission::COMPLETED_DOWNLOAD_CONFIRMED,
                                     VBADocuments::UploadSubmission::COMPLETED_UPLOAD_SUCCEEDED)
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(resp)
      upload_success.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_success.guid)
      expect(updated.status).to eq('vbms')
      expect(updated.metadata['completed_details']).to eq(JSON.parse(resp).first.first['packets'])
    end

    it 'updates completed status from upstream to SUCCESS and marked as final' do
      resp = status_complete_packets(VBADocuments::UploadSubmission::COMPLETED_DOWNLOAD_CONFIRMED)
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(resp)
      upload_success.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_success.guid)
      expect(updated.status).to eq('success')
      expect(updated.metadata[VBADocuments::UploadSubmission::FINAL_SUCCESS_STATUS_KEY]).not_to be(nil)
    end

    it 'updates completed status from upstream to ERROR if any UNIDENTIFIABLE_MAIL' do
      resp = status_complete_packets(VBADocuments::UploadSubmission::COMPLETED_DOWNLOAD_CONFIRMED,
                                     VBADocuments::UploadSubmission::COMPLETED_UNIDENTIFIABLE_MAIL,
                                     VBADocuments::UploadSubmission::COMPLETED_DOWNLOAD_CONFIRMED)
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(resp)
      upload_success.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_success.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC202')
      expect(updated.detail).to eq("Upstream status: #{VBADocuments::UploadSubmission::ERROR_UNIDENTIFIED_MAIL}")
    end

    it 'Logs an error if no packets are sent' do
      resp = status_complete_packets
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(resp)
      upload_success.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_success.guid)
      expect(updated.status).to eq('success')
    end

    it 'Logs an error if no completedReason keys are sent' do
      resp = [[{
        uuid: 'ignored',
        status: 'Complete',
        errorMessage: '',
        lastUpdated: '2018-04-25 00:02:39',
        packets: [
          {
            veteranId: '777889999',
            status: 'Complete',
            transactionDate: '2018-04-25 00:02:39'
          }
        ]
      }]].to_json

      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(resp)
      upload_success.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_success.guid)
      expect(updated.status).to eq('success')
    end

    it 'updates success status from upstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(success_body)
      upload_processing.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_processing.guid)
      expect(updated.status).to eq('success')
    end

    it 'updates error status from upstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(processing_error_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC202')
      expect(updated.detail).to include('Invalid splines')
    end

    it 'updates processing error status from upstream' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(error_body)
      upload_received.refresh_status!
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC202')
      expect(updated.detail).to include('Invalid splines')
    end

    it 'skips upstream status check if not yet submitted' do
      expect(client_stub).not_to receive(:status)
      upload_pending.refresh_status!
    end

    it 'skips upstream status check if already in error state' do
      expect(client_stub).not_to receive(:status)
      upload_error.refresh_status!
    end

    it 'skips upstream status check if already in vbms state' do
      expect(client_stub).not_to receive(:status)
      upload_vbms.refresh_status!
    end

    it 'raises on error status from upstream without updating state' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(false)
      expect(faraday_response).to receive(:status).and_return(401)
      expect(faraday_response).to receive(:body).at_least(:once).and_return('Unauthorized')
      expect { upload_received.refresh_status! }.to raise_error(Common::Exceptions::BadGateway)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'raises on duplicate error status from upstream and updates state' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(false)
      expect(faraday_response).to receive(:status).and_return(401)
      expect(faraday_response).to receive(:body).at_least(:once).and_return('Document already uploaded with uuid')
      expect { upload_received.refresh_status! }.to raise_error(Common::Exceptions::BadGateway)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'raises on unexpected status from upstream without updating state' do
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return(nonsense_body)
      expect { upload_received.refresh_status! }.to raise_error(Common::Exceptions::BadGateway)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload_received.guid)
      expect(updated.status).to eq('received')
    end

    it 'ignores empty status from upstream for known uuid' do
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

    it 'records status change times properly' do
      time = Time.zone.now
      Timecop.freeze(time)
      upload = VBADocuments::UploadSubmission.new
      Timecop.freeze(time + 1.minute)
      upload.status = 'uploaded'
      upload.save!
      elapsed = upload.metadata['status']['pending']['end'] - upload.metadata['status']['pending']['start']
      expect(elapsed).to be == 60
    end

    it 'records status changes' do
      upload = VBADocuments::UploadSubmission.new
      upload.status = 'uploaded'
      upload.save!
      expect(upload.metadata['status']['pending']['start'].class).to be == Integer
      expect(upload.metadata['status']['pending']['end'].class).to be == Integer
      expect(upload.metadata['status']['uploaded']['start'].class).to be == Integer
      expect(upload.metadata['status']['uploaded']['end'].class).to be == NilClass
      upload.status = 'error'
      upload.save!
      expect(upload.metadata['status']['uploaded']['end'].class).to be == Integer
      expect(upload.metadata['status']['error']['start'].class).to be == Integer
    end

    it 'records status changes after being found' do
      upload = VBADocuments::UploadSubmission.new
      upload.status = 'uploaded'
      upload.save!
      found = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      found.status = 'error'
      found.save!
      expect(found.metadata['status']['uploaded']['end'].class).to be == Integer
      expect(found.metadata['status']['error']['start'].class).to be == Integer
    end

    it 'does not allow the same guid used twice' do
      upload1 = VBADocuments::UploadSubmission.new
      upload2 = VBADocuments::UploadSubmission.new
      saved = upload1.save
      expect(saved).to eq(true)
      guid = upload1.guid
      upload2.guid = guid
      saved = upload2.save
      expect(saved).to eq(false)
    end
  end

  context 'aged_processing' do
    it 'can find submissions that have been in-flight for too long' do
      states = %w[pending uploaded received processing]
      states.each do |state|
        u = VBADocuments::UploadSubmission.new
        u.status = state
        u.save!
      end
      time = Time.zone.now
      Timecop.freeze(time)
      # find nothing
      states.each do |status|
        ancient_in_flights = VBADocuments::UploadSubmission.aged_processing(14, :days, status).to_a
        expect(ancient_in_flights.count).to eq 0
      end

      Timecop.freeze(time + 14.days + 1.minute)
      # find four things, one in each state
      states.each do |status|
        ancient_in_flights = VBADocuments::UploadSubmission.aged_processing(14, :days, status).to_a
        expect(ancient_in_flights.count).to eq 1
      end
    end

    it 'can order the aged_processing' do
      status = 'uploaded'
      3.times do |i|
        %i[days minutes hours].each do |unit|
          u = VBADocuments::UploadSubmission.new
          u.status = status
          u.save!
          u.metadata['status'][status]['start'] = i.send(unit).ago.to_i
          u.save!
        end
      end
      models = nil
      Timecop.travel(1.second.from_now) do
        models = VBADocuments::UploadSubmission.aged_processing(0, :days, status)
      end
      times = []
      models.each { |e| times << e.metadata['status'][status]['start'] }
      expect(times.sort).to eq times
    end
  end

  describe '#appeals_consumer?' do
    it 'returns true if #consumer_name is appeals specific' do
      upload = FactoryBot.create(:upload_submission, consumer_name: 'appeals_api_sc_evidence_submission')

      expect(upload.appeals_consumer?).to eq(true)
    end

    it 'returns false if #consumer_name is not appeals specific' do
      upload = FactoryBot.create(:upload_submission, consumer_name: 'unrelated')

      expect(upload.appeals_consumer?).to eq(false)
    end
  end

  describe '#base64_encoded?' do
    it 'returns true if metadata["base64_encoded"] is true' do
      upload = FactoryBot.create(:upload_submission, metadata: { 'base64_encoded' => true })

      expect(upload.base64_encoded?).to eq(true)
    end

    it 'returns false if metadata["base64_encoded"] is false' do
      upload = FactoryBot.create(:upload_submission, metadata: { 'base64_encoded' => false })

      expect(upload.base64_encoded?).to eq(false)
    end

    it 'returns false if metadata["base64_encoded"] is nil' do
      upload = FactoryBot.create(:upload_submission)

      expect(upload.base64_encoded?).to eq(false)
    end
  end

  describe '#track_upload_timeout_error' do
    let(:upload) { FactoryBot.create(:upload_submission) }

    context 'when this is the first timeout error' do
      before { upload.track_upload_timeout_error }

      it 'sets the "upload_timeout_error_count" metadata to 1' do
        expect(upload.metadata['upload_timeout_error_count']).to be(1)
      end
    end

    context 'when this is the third timeout error' do
      before do
        3.times do
          upload.track_upload_timeout_error
        end
      end

      it 'sets the "upload_timeout_error_count" metadata to 3' do
        expect(upload.metadata['upload_timeout_error_count']).to be(3)
      end
    end
  end

  describe '#hit_upload_timeout_limit?' do
    let(:retry_limit) { described_class::UPLOAD_TIMEOUT_RETRY_LIMIT }

    context 'when "upload_timeout_error_count" is smaller than the retry limit' do
      let(:error_count) { retry_limit - 1 }
      let(:upload) { FactoryBot.create(:upload_submission, metadata: { 'upload_timeout_error_count' => error_count }) }

      it 'returns false' do
        expect(upload.hit_upload_timeout_limit?).to be(false)
      end
    end

    context 'when "upload_timeout_error_count" is equal to the retry limit' do
      let(:error_count) { retry_limit }
      let(:upload) { FactoryBot.create(:upload_submission, metadata: { 'upload_timeout_error_count' => error_count }) }

      it 'returns false' do
        expect(upload.hit_upload_timeout_limit?).to be(false)
      end
    end

    context 'when "upload_timeout_error_count" is larger than the retry limit' do
      let(:error_count) { retry_limit + 1 }
      let(:upload) { FactoryBot.create(:upload_submission, metadata: { 'upload_timeout_error_count' => error_count }) }

      it 'returns true' do
        expect(upload.hit_upload_timeout_limit?).to be(true)
      end
    end
  end
end
