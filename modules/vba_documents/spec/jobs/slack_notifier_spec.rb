# frozen_string_literal: true

require 'rails_helper'
#require_relative '../support/vba_document_fixtures'

RSpec.describe VBADocuments::SlackNotifier, type: :job do

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:slack_settings) { {
      'in_flight_notification_hung_time_in_days' => 14,
      'renotification_in_minutes' => 240,
      'update_stalled_notification_in_minutes' => 180,
      'daily_notification_hour' => 7
  } }

  before do
    allow(faraday_response).to receive(:success?).and_return(true)
    @job = described_class.new
    allow(@job).to receive(:send_to_slack) {
      faraday_response
    }
    @results = nil
  end

  context 'daily notification' do

    it 'does the daily notification at the correct hour' do
      with_settings(Settings.vba_documents.slack, slack_settings) do
        Timecop.freeze(Time.at(1616673917).utc) do
          #Time.at(1616673917).utc.hour is 12 (12 - 5 is 7 (5 is EST time offset)). See daily_notification_hour above
          @results = @job.perform
        end
        expect(@results[:daily_notification]).to be(true)
      end
    end

    it 'does not do the daily notification at the incorrect hour' do
      with_settings(Settings.vba_documents.slack, slack_settings) do
        Timecop.freeze(1616657401) do
          #Time.at(1616657401).utc.hour is not 12
          @results = @job.perform
        end
        expect(@results).to have_key(:daily_notification)
        expect(@results[:daily_notification]).to be(nil)
      end
    end
  end

  context 'long_flyers only' do
    before do
      u = VBADocuments::UploadSubmission.new
      status = 'success'
      u.status = status
      u.save!
      u.metadata['status'][status]['start'] = 5.years.ago.to_i
      u.save!
    end

    it "notifies when submission are in flight for too long" do
      with_settings(Settings.vba_documents.slack, slack_settings) do
        @results = @job.perform
        expect(@results[:long_flyers_alerted]).to be(true)
        expect(@results[:upload_stalled_alerted]).to be(nil)
      end
    end

    it "does not over notify even when submissions are in flight for too long" do
      with_settings(Settings.vba_documents.slack, slack_settings) do
        @job.perform
        @results = @job.perform
        expect(@results[:long_flyers_alerted]).to be(nil)
        travel_time = Settings.vba_documents.slack.renotification_in_minutes + 1
        Timecop.travel(travel_time.minutes.from_now) do
          @results = @job.perform
          expect(@results[:long_flyers_alerted]).to be(true)
          Timecop.travel(1.minutes.from_now) do
          @results = @job.perform
          expect(@results[:long_flyers_alerted]).to be(nil)
          end
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

    it "notifies when submission are in uploaded for too long" do
      with_settings(Settings.vba_documents.slack, slack_settings) do
        @results = @job.perform
        expect(@results[:upload_stalled_alerted]).to be(true)
        expect(@results[:long_flyers_alerted]).to be(nil)
      end
    end

    it "does not over notify even when submissions are in uploaded for too long" do
      with_settings(Settings.vba_documents.slack, slack_settings) do
        @job.perform
        @results = @job.perform
        expect(@results[:upload_stalled_alerted]).to be(nil)
        travel_time = Settings.vba_documents.slack.renotification_in_minutes + 1
        Timecop.travel(travel_time.minutes.from_now) do
          @results = @job.perform
          expect(@results[:upload_stalled_alerted]).to be(true)
          Timecop.travel(1.minutes.from_now) do
            @results = @job.perform
            expect(@results[:upload_stalled_alerted]).to be(nil)
          end
        end
      end
    end
  end

end

