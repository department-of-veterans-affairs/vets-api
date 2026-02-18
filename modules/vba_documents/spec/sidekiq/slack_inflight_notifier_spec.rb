# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/app/sidekiq/vba_documents/slack_inflight_notifier'

RSpec.describe 'VBADocuments::SlackInflightNotifier', type: :job do
  let(:slack_messenger) { instance_double(VBADocuments::Slack::Messenger) }
  let(:slack_enabled) { true }

  before do
    allow(Settings.vba_documents.slack).to receive_messages(
      in_flight_notification_hung_time_in_days: 14,
      renotification_in_minutes: 240,
      update_stalled_notification_in_minutes: 180,
      enabled: slack_enabled
    )
    allow(Flipper).to receive(:enabled?).with(:decision_review_delay_evidence).and_return(false)
    allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    @job = VBADocuments::SlackInflightNotifier.new
    @results = nil
  end

  context 'when flag is disabled' do
    let(:slack_enabled) { false }

    it 'does nothing' do
      with_settings(Settings.vba_documents.slack, enabled: false) do
        @results = @job.perform
        expect(slack_messenger).not_to have_received(:notify!)
        expect(@results).to be_nil
      end
    end
  end

  context 'summary notification' do
    let(:upload_submission) { VBADocuments::UploadSubmission.create(status: 'received') }

    around do |example|
      Timecop.freeze(Time.zone.now) { example.run }
    end

    before do
      upload_submission.metadata['status']['received']['start'] = 5.days.ago.to_i
      upload_submission.save!
    end

    it 'notifies on every run' do
      @results = @job.perform
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: include("Status 'received': 1 submissions exceed thresholds")
                     .and(include("GUID: #{upload_submission.guid} | Status: received | Duration: 5 days"))
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    it 'sends an informational summary when submissions are below thresholds' do
      upload_submission.metadata['status']['received']['start'] = 3.days.ago.to_i
      upload_submission.save!

      @results = @job.perform
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: "\nNo submissions exceed thresholds."
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    it 'notifies for processing status when exceeding 8-day threshold' do
      processing_submission = VBADocuments::UploadSubmission.create(status: 'processing')
      processing_submission.metadata['status']['processing']['start'] = 9.days.ago.to_i
      processing_submission.save!

      @results = @job.perform
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: include("GUID: #{processing_submission.guid} | Status: processing")
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    it 'notifies for uploaded status when exceeding 26-hour threshold' do
      uploaded_submission = VBADocuments::UploadSubmission.create(status: 'uploaded')
      uploaded_submission.metadata['status']['uploaded']['start'] = 27.hours.ago.to_i
      uploaded_submission.save!

      @results = @job.perform
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: include("GUID: #{uploaded_submission.guid} | Status: uploaded")
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    it 'excludes submissions older than 9 days from notifications' do
      upload_submission.metadata['status']['received']['start'] = 3.days.ago.to_i
      upload_submission.save!

      old_submission = VBADocuments::UploadSubmission.create(status: 'received', created_at: 10.days.ago)
      old_submission.metadata['status']['received']['start'] = 10.days.ago.to_i
      old_submission.save!

      @results = @job.perform
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: "\nNo submissions exceed thresholds."
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    it 'includes multiple submissions exceeding thresholds in a single notification' do
      uploaded_submission = VBADocuments::UploadSubmission.create(status: 'uploaded')
      uploaded_submission.metadata['status']['uploaded']['start'] = 27.hours.ago.to_i
      uploaded_submission.save!

      processing_submission = VBADocuments::UploadSubmission.create(status: 'processing')
      processing_submission.metadata['status']['processing']['start'] = 9.days.ago.to_i
      processing_submission.save!

      @results = @job.perform
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: include("GUID: #{uploaded_submission.guid} | Status: uploaded")
                     .and(include("GUID: #{processing_submission.guid} | Status: processing"))
                     .and(include("GUID: #{upload_submission.guid} | Status: received"))
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    context 'when the :decision_review_delay_evidence feature is enabled' do
      before do
        VBADocuments::UploadSubmission.create(status: 'uploaded',
                                              consumer_name: 'appeals_api_sc_evidence_submission').tap do |sub|
          sub.metadata['status']['uploaded']['start'] = 2.days.ago.to_i
          sub.save!
        end
        allow(Flipper).to receive(:enabled?).with(:decision_review_delay_evidence).and_return(true)
      end

      it 'excludes evidence submissions from the "uploaded" status grouping' do
        @results = @job.perform
        expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
          {
            class: 'VBADocuments::SlackInflightNotifier',
            alert: 'Submissions Exceeding Thresholds',
            details: include("Status 'received': 1 submissions exceed thresholds")
                       .and(include("GUID: #{upload_submission.guid} | Status: received | Duration: 5 days"))
          }
        )
        expect(slack_messenger).to have_received(:notify!).once
        expect(@results[:summary_notification]).to be(true)
      end
    end

    context 'when the :decision_review_delay_evidence feature is disabled' do
      let(:appeals_submission) do
        VBADocuments::UploadSubmission.create(status: 'uploaded', consumer_name: 'appeals_api_sc_evidence_submission')
      end

      before do
        appeals_submission.metadata['status']['uploaded']['start'] = 2.days.ago.to_i
        appeals_submission.save!
      end

      it 'includes evidence submissions in the "uploaded" status grouping' do
        @results = @job.perform
        expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
          {
            class: 'VBADocuments::SlackInflightNotifier',
            alert: 'Submissions Exceeding Thresholds',
            details: include("Status 'uploaded': 1 submissions exceed thresholds")
                       .and(include("GUID: #{appeals_submission.guid} | Status: uploaded | Duration: 2 days"))
                       .and(include("Status 'received': 1 submissions exceed thresholds"))
                       .and(include("GUID: #{upload_submission.guid} | Status: received | Duration: 5 days"))
          }
        )
        expect(slack_messenger).to have_received(:notify!).once
        expect(@results[:summary_notification]).to be(true)
      end
    end

    it 'limits reported violations per status to AGED_PROCESSING_QUERY_LIMIT' do
      11.times do
        VBADocuments::UploadSubmission.create(status: 'processing').tap do |sub|
          sub.metadata['status']['processing']['start'] = 9.days.ago.to_i
          sub.save!
        end
      end

      @results = @job.perform

      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackInflightNotifier',
          alert: 'Submissions Exceeding Thresholds',
          details: include("Status 'processing': 11 submissions exceed thresholds (showing up to 10).")
        }
      )
      expect(@results[:summary_notification]).to be(true)
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
      expect(slack_messenger).to have_received(:notify!).twice
      expect(@results[:long_flyers_alerted]).to be(true)
      expect(@results[:upload_stalled_alerted]).to be_nil
    end

    it 'does not over notify even when submissions are in flight for too long' do
      @job.perform
      @results = @job.perform
      expect(@results[:long_flyers_alerted]).to be_nil

      travel_time = Settings.vba_documents.slack.renotification_in_minutes + 1
      Timecop.travel(travel_time.minutes.from_now) do
        @results = @job.perform
        expect(@results[:long_flyers_alerted]).to be(true)

        Timecop.travel(1.minute.from_now) do
          @results = @job.perform
          expect(@results[:long_flyers_alerted]).to be_nil
        end
      end
      expect(slack_messenger).to have_received(:notify!).exactly(6).times
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

      u = VBADocuments::UploadSubmission.find_by(guid:)
      expect(last_notified).to be < u.metadata['last_slack_notification'].to_i
    end
  end

  context 'invalid parts' do
    before do
      u = VBADocuments::UploadSubmission.new
      u.metadata['invalid_parts'] = %w[banana monkey]
      u.save!
    end

    it 'notifies when invalid parts exist' do
      @results = @job.perform
      expect(slack_messenger).to have_received(:notify!).twice
      expect(@results[:invalid_parts_alerted]).to be(true)
    end

    it 'does not notify more than once when invalid parts exist' do
      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be(true)

      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be_nil
      expect(slack_messenger).to have_received(:notify!).exactly(3).times
    end
  end

  context 'upload stalled alert' do
    before do
      allow(Flipper).to receive(:enabled?).with(:decision_review_delay_evidence).and_return(true)
      VBADocuments::UploadSubmission.create(status: 'uploaded', consumer_name: 'appeals_api_sc_evidence_submission')
                                    .tap do |sub|
                                      sub.metadata['status']['uploaded']['start'] = 200.minutes.ago.to_i
                                      sub.save!
      end
      @job.send(:fetch_settings)
    end

    it 'does not alert on evidence submissions when delay is enabled' do
      @job.send(:upload_stalled_alert)
      expect(slack_messenger).not_to have_received(:notify!)
    end
  end
end
