# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/app/sidekiq/vba_documents/slack_expired_notifier'

RSpec.describe 'VBADocuments::SlackExpiredNotifier', type: :job do
  let(:slack_messenger) { instance_double(VBADocuments::Slack::Messenger.class_name) }
  let(:slack_enabled) { true }

  before do
    allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    allow(Settings.vba_documents.slack).to receive(:enabled).and_return(slack_enabled)
    @job = VBADocuments::SlackExpiredNotifier.new
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
      VBADocuments::UploadSubmission.new(status: 'pending', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'uploaded', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'received', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'processing', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'success', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'vbms', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'error', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'expired', consumer_name: 'sometech', created_at: 5.days.ago).save!
    end

    it 'does nothing' do
      @results = @job.perform
      expect(slack_messenger).not_to have_received(:notify!)
    end
  end

  context 'when expired uploads are found and exceed the reporting threshold' do
    before do
      VBADocuments::UploadSubmission.new(status: 'uploaded', consumer_name: 'sometech').save!
      VBADocuments::UploadSubmission.new(status: 'expired', consumer_name: 'vagov').save!
    end

    it 'warns using slack' do
      t = 1.hour.ago.change(zone: 'Eastern Time (US & Canada)').strftime('%Y-%m-%d %I:%M:%S %p %Z')
      @results = @job.perform
      expect(slack_messenger).to have_received(:notify!).once
      expect(VBADocuments::Slack::Messenger).to have_received(:new).with(
        {
          class: 'VBADocuments::SlackExpiredNotifier',
          alert: "1(50.0%) out of 2 Benefits Intake uploads created since #{t} " \
                 'have expired with no consumer uploads to S3' \
                 "\nThis could indicate an S3 issue impacting consumers.",
          details: "\n\t(Consumer, Expired Rate)\n\tvagov: 100.0%\n\tsometech: 0.0%\n"
        }
      )
    end
  end
end
