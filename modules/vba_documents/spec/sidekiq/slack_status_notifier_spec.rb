# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/app/sidekiq/vba_documents/slack_status_notifier'

RSpec.describe 'VBADocuments::SlackStatusNotifier', type: :job do
  let(:slack_messenger) { instance_double(VBADocuments::Slack::Messenger.class_name) }
  let(:slack_enabled) { true }

  before do
    allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    allow(Settings.vba_documents.slack).to receive(:enabled).and_return(slack_enabled)
    @job = VBADocuments::SlackStatusNotifier.new
    @results = nil
  end

  context 'when flag is disabled' do
    let(:slack_enabled) { false }

    it 'does nothing' do
      with_settings(Settings.vba_documents.slack, enabled: false) do
        @results = @job.perform
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end
  end

  context 'when no new expired uploads were found' do
    before do
      create(:upload_submission, status: 'pending', consumer_name: 'sometech')
      create(:upload_submission, status: 'uploaded', consumer_name: 'sometech')
      create(:upload_submission, status: 'received', consumer_name: 'sometech')
      create(:upload_submission, status: 'processing', consumer_name: 'sometech')
      create(:upload_submission, status: 'success', consumer_name: 'sometech')
      create(:upload_submission, status: 'vbms', consumer_name: 'sometech')
      create(:upload_submission, status: 'error', consumer_name: 'sometech')
      create(:upload_submission, status: 'expired', consumer_name: 'sometech', created_at: 5.days.ago)
    end

    it 'does nothing' do
      @results = @job.perform
      expect(slack_messenger).not_to have_received(:notify!)
    end
  end

  context 'when expired uploads are found and exceed the reporting threshold' do
    before do
      create(:upload_submission, status: 'uploaded', consumer_name: 'sometech')
      create(:upload_submission, status: 'expired', consumer_name: 'vagov')
    end

    it 'warns using slack' do
      t = 1.hour.ago.in_time_zone('America/New_York').strftime('%Y-%m-%d %I:%M:%S %p %Z')
      @results = @job.perform
      expect(slack_messenger).to have_received(:notify!).once
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackStatusNotifier',
          alert: "1(50.0%) out of 2 Benefits Intake uploads created since #{t} " \
                 'have expired with no consumer uploads to S3' \
                 "\nThis could indicate an S3 issue impacting consumers.",
          details: "\n\t(Consumer, Expired Rate)\n\tvagov: 100.0%\n\tsometech: 0.0%\n"
        }
      )
    end
  end

  context 'when no new uploaded uploads were found' do
    before do
      create(:upload_submission, status: 'pending', consumer_name: 'sometech2')
      create(:upload_submission, status: 'uploaded', consumer_name: 'sometech')
      create(:upload_submission, status: 'received', consumer_name: 'sometech')
      create(:upload_submission, status: 'processing', consumer_name: 'sometech')
      create(:upload_submission, status: 'success', consumer_name: 'sometech')
      create(:upload_submission, status: 'vbms', consumer_name: 'sometech')
      create(:upload_submission, status: 'error', consumer_name: 'sometech')
      create(:upload_submission, status: 'expired', consumer_name: 'sometech', created_at: 5.days.ago)
    end

    it 'does nothing' do
      @results = @job.perform
      expect(slack_messenger).not_to have_received(:notify!)
    end
  end

  context 'when uploaded uploads are found' do
    before do
      # should pick up since its 5.5 hours old
      @us_uploaded = create(:upload_submission,
                            status: 'uploaded',
                            consumer_name: 'sometech2',
                            created_at: 5.5.hours.ago)

      # should not pick up wrong status
      create(:upload_submission, status: 'vbms', consumer_name: 'vagov')

      # should not pick up, uploaded status but not old enough yet
      create(:upload_submission, status: 'uploaded', consumer_name: 'sometech2')

      # should not pick up, uploaded status, but since appeal evidense sub are not considered
      # stuck until they hit their potential max delay of 24 hours plus 100 minutes
      create(:upload_submission,
             status: 'uploaded',
             consumer_name: 'appeals_api_nod_evidence_submission',
             created_at: 5.5.hours.ago)

      @es_us_uploaded = create(:upload_submission,
                               status: 'uploaded',
                               consumer_name: 'appeals_api_nod_evidence_submission',
                               created_at: 27.hours.ago)
    end

    it 'warns using slack' do
      @results = @job.perform
      expect(slack_messenger).to have_received(:notify!).once
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackStatusNotifier',
          alert: '2 Benefits Intake Submissions have been in the uploaded status for longer than expected. ' \
                 'This could indicate an issue with Benefits Intake or Central Mail',
          details: "Oldest 20 Stuck Upload Submissions\n\n\t(Guid, Age(Hours:Minutes), " \
                   "upload retry count\n, upload size), detail\n" \
                   "\t#{@es_us_uploaded.guid} 27:00 0  \n" \
                   "\t#{@us_uploaded.guid} 5:30 0  \n"
        }
      )
    end
  end
end
