# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/app/workers/vba_documents/slack_notifier'

RSpec.describe 'VBADocuments::SlackNotifier', type: :job do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:slack_enabled) { true }

  before do
    allow(Settings.vba_documents.slack).to receive(:in_flight_notification_hung_time_in_days).and_return(14)
    allow(Settings.vba_documents.slack).to receive(:renotification_in_minutes).and_return(240)
    allow(Settings.vba_documents.slack).to receive(:update_stalled_notification_in_minutes).and_return(180)
    allow(Settings.vba_documents.slack).to receive(:daily_notification_hour).and_return(7)
    allow(Settings.vba_documents.slack).to receive(:default_alert_url).and_return('')
    allow(Settings.vba_documents.slack).to receive(:enabled).and_return(slack_enabled)
    allow(faraday_response).to receive(:success?).and_return(true)
    @job = VBADocuments::SlackNotifier.new
    allow(@job).to receive(:send_to_slack) {
      faraday_response
    }
    @results = nil
  end

  context 'when flag is disabled' do
    let(:slack_enabled) { false }

    it 'does nothing' do
      with_settings(Settings.vba_documents.slack, enabled: false) do
        @results = @job.perform
        expect(@results).to be(nil)
      end
    end
  end

  context 'daily notification' do
    it 'does the daily notification at the correct hour' do
      Timecop.freeze(Time.at(1_616_673_917).utc) do
        # Time.at(1616673917).utc.hour is 12 (12 - 5 is 7 (5 is EST time offset)). See daily_notification_hour above
        @results = @job.perform
      end
      expect(@results[:daily_notification]).to be(true)
    end

    it 'does not do the daily notification at the incorrect hour' do
      Timecop.freeze(Time.at(1_616_657_401).utc) do
        # Time.at(1616657401).utc.hour is not 12
        @results = @job.perform
      end
      expect(@results).to have_key(:daily_notification)
      expect(@results[:daily_notification]).to be(nil)
    end
  end

  context 'long_flyers only' do
    before do
      u = VBADocuments::UploadSubmission.new
      status = 'received'
      u.status = status
      u.save!
      u.metadata['status'][status]['start'] = 5.years.ago.to_i
      u.save!
    end

    it 'notifies when submission are in flight for too long' do
      @results = @job.perform
      expect(@results[:long_flyers_alerted]).to be(true)
      expect(@results[:upload_stalled_alerted]).to be(nil)
    end

    it 'does not over notify even when submissions are in flight for too long' do
      @job.perform
      @results = @job.perform
      expect(@results[:long_flyers_alerted]).to be(nil)
      travel_time = Settings.vba_documents.slack.renotification_in_minutes + 1
      Timecop.travel(travel_time.minutes.from_now) do
        @results = @job.perform
        expect(@results[:long_flyers_alerted]).to be(true)
        Timecop.travel(1.minute.from_now) do
          @results = @job.perform
          expect(@results[:long_flyers_alerted]).to be(nil)
        end
      end
    end
  end

  context 'stalled uploads only' do
    before do
      u = VBADocuments::UploadSubmission.new
      status = 'uploaded'
      u.status = status
      u.save!
      u.metadata['status'][status]['start'] = 5.years.ago.to_i
      u.save!
    end

    it 'notifies when submission are in uploaded for too long' do
      @results = @job.perform
      expect(@results[:upload_stalled_alerted]).to be(true)
      expect(@results[:long_flyers_alerted]).to be(nil)
    end

    it 'does not over notify even when submissions are in uploaded for too long' do
      @job.perform
      @results = @job.perform
      expect(@results[:upload_stalled_alerted]).to be(nil)
      travel_time = Settings.vba_documents.slack.renotification_in_minutes + 1
      Timecop.travel(travel_time.minutes.from_now) do
        @results = @job.perform
        expect(@results[:upload_stalled_alerted]).to be(true)
        Timecop.travel(1.minute.from_now) do
          @results = @job.perform
          expect(@results[:upload_stalled_alerted]).to be(nil)
        end
      end
    end
  end

  it 're-notifies if at least one requires notification' do
    u = VBADocuments::UploadSubmission.new
    status = 'received'
    u.status = status
    u.save!
    u.metadata['status'][status]['start'] = 5.years.ago.to_i
    u.save!
    @job.perform
    u.reload
    last_notified = u.metadata['last_slack_notification'].to_i # nil to zero
    guid = u.guid
    u = VBADocuments::UploadSubmission.new
    status = 'received'
    u.status = status
    u.save!
    u.metadata['status'][status]['start'] = 5.years.ago.to_i
    u.save!
    Timecop.travel(1.minute.from_now) do
      @job.perform
    end
    u = VBADocuments::UploadSubmission.find_by(guid: guid)
    expect(last_notified).to be < u.metadata['last_slack_notification'].to_i
  end

  context 'invalid parts' do
    before do
      u = VBADocuments::UploadSubmission.new
      u.metadata['invalid_parts'] = %w[banana monkey]
      u.save!
    end

    it 'notifies when invalid parts exist' do
      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be(true)
    end

    it 'does not notify more than once when invalid parts exist' do
      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be(true)
      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be(nil)
    end
  end
end
