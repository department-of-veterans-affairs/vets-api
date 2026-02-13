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
          details: "\n\tGUID: #{upload_submission.guid} | Status: received | Duration: 5 days"
        }
      )
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:summary_notification]).to be(true)
    end

    context 'when the :decision_review_delay_evidence feature is enabled' do
      before do
        # Create an appeals submission that would be included if the flag were off
        VBADocuments::UploadSubmission.create(status: 'uploaded',
                                              consumer_name: 'appeals_api_sc_evidence_submission').tap do |sub|
          sub.metadata['status']['uploaded']['start'] = 2.days.ago.to_i
          sub.save!
        end
        allow(Flipper).to receive(:enabled?).with(:decision_review_delay_evidence).and_return(true)
      end

      it 'excludes evidence submissions from the "uploaded" status grouping' do
        @results = @job.perform
        # The existing 'received' submission will still trigger a notification
        expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
          {
            class: 'VBADocuments::SlackInflightNotifier',
            alert: 'Submissions Exceeding Thresholds',
            details: "\n\tGUID: #{upload_submission.guid} | Status: received | Duration: 5 days"
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
        # Create an appeals submission that will be included
        appeals_submission.metadata['status']['uploaded']['start'] = 2.days.ago.to_i
        appeals_submission.save!
      end

      it 'includes evidence submissions in the "uploaded" status grouping' do
        @results = @job.perform
        expected_details = "\n\tGUID: #{appeals_submission.guid} | Status: uploaded | Duration: 2 days" \
                           "\n\tGUID: #{upload_submission.guid} | Status: received | Duration: 5 days"
        expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
          {
            class: 'VBADocuments::SlackInflightNotifier',
            alert: 'Submissions Exceeding Thresholds',
            details: expected_details
          }
        )
        expect(slack_messenger).to have_received(:notify!).once
        expect(@results[:summary_notification]).to be(true)
      end
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
      expect(slack_messenger).to have_received(:notify!).twice # once for long flyers and once for summary
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
      expect(slack_messenger).to have_received(:notify!).exactly(6).times # twice for long flyers and 4x for summary
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
      expect(slack_messenger).to have_received(:notify!).once
      expect(@results[:invalid_parts_alerted]).to be(true)
    end

    it 'does not notify more than once when invalid parts exist' do
      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be(true)

      @results = @job.perform
      expect(@results[:invalid_parts_alerted]).to be_nil
      expect(slack_messenger).to have_received(:notify!).once
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
