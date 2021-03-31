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

    context 'averages' do
      before do
        time = Time.zone.now
        consumer_1 = VBADocuments::UploadSubmission.new
        consumer_1.consumer_name = 'consumer_1'
        @num_times = 5
        @num_times.times do |index|
          Timecop.freeze(time)
          upload = VBADocuments::UploadSubmission.new
          upload.consumer_name = "consumer_#{index}"
          Timecop.travel(time + 1.minute)
          upload.status = 'uploaded'
          upload.save
        end
        consumer_1.status = 'uploaded'
        consumer_1.save
      end

      #  rspec ./modules/vba_documents/spec/models/upload_submission_spec.rb
      it 'calculates status averages' do
        avg_times = VBADocuments::UploadSubmission.status_elapsed_times(1.year.ago, 1.minute.from_now).first
        avg_times_c1 = VBADocuments::UploadSubmission
                       .status_elapsed_times(1.year.ago, 1.minute.from_now, 'consumer_1').first
        expect(avg_times['avg_secs'].to_i).to be == 60
        expect(avg_times['min_secs'].to_i).to be == 60
        expect(avg_times['max_secs'].to_i).to be == 60
        expect(avg_times['rowcount'].to_i).to be == @num_times + 1
        expect(avg_times['status']).to eq('pending')
        expect(avg_times_c1['avg_secs'].to_i).to be == 60
        expect(avg_times_c1['rowcount'].to_i).to be == 2
        expect(avg_times_c1['status']).to eq('pending')
      end
    end

    it 'records status change times properly' do
      time = Time.zone.now
      Timecop.freeze(time)
      upload = VBADocuments::UploadSubmission.new
      Timecop.travel(time + 1.minute)
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

      Timecop.travel(time + 14.days + 1.minute)
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
end
