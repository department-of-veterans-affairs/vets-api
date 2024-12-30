# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

RSpec.describe Lighthouse::BenefitsDocuments::FailureNotificationEmailJob, type: :job do
  subject { described_class }

  let(:notify_client_stub) { instance_double(VaNotify::Service) }
  let(:user_account) { create(:user_account) }
  let(:filename) { 'docXXXX-XXte.pdf' }
  let(:icn) { user_account.icn }
  let(:first_name) { 'Bob' }
  let(:issue_instant) { Time.now.to_i }
  let(:formatted_submit_date) do
    # We want to return all times in EDT
    timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end
  let(:date_submitted) { formatted_submit_date }
  let(:date_failed) { formatted_submit_date }

  let(:notification_id) { SecureRandom.uuid }

  let(:vanotify_service) do
    service = instance_double(VaNotify::Service)

    response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
    allow(service).to receive(:send_email).and_return(response)

    service
  end

  before do
    allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
    allow(Rails.logger).to receive(:info)
  end

  context 'when there are no FAILED records' do
    it 'doesnt send anything' do
      expect(EvidenceSubmission).not_to receive(:update)
      expect(vanotify_service).not_to receive(:send_email)
      expect(EvidenceSubmission.va_notify_email_queued.length).to equal(0)
      subject.new.perform
    end
  end

  context 'when there is a FAILED record with a va_notify_date' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
      create(:bd_evidence_submission_failed_va_notify_email_enqueued)
    end

    it 'doesnt update an evidence submission record or queue failure email' do
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
      subject.new.perform
      expect(vanotify_service).not_to receive(:send_email)
      # This is 1 since is has already been queued
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
    end
  end

  context 'when there is a FAILED record without a va_notify_date and an error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
      allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let!(:evidence_submission_failed) { create(:bd_evidence_submission_failed) }
    let(:error_message) { "#{evidence_submission_failed.job_class} va notify failure email errored" }
    let(:tags) { ['service:claim-status', "function: #{error_message}"] }

    it 'handles the error and increments the statsd metric' do
      expect(EvidenceSubmission.count).to eq(1)
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(0)
      expect(vanotify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: 'StandardError' })
      expect(StatsD).to receive(:increment).with('silent_failure', tags: tags)
      subject.new.perform
    end
  end

  context 'when there is 1 FAILED record without a va_notify_date' do
    let(:tags) { ['service:claim-status', "function: #{message}"] }
    let!(:evidence_submission_failed) { create(:bd_evidence_submission_failed) }
    let(:message) { "#{evidence_submission_failed.job_class} va notify failure email queued" }

    before do
      allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
      allow(Rails.logger).to receive(:info)
      allow(StatsD).to receive(:increment)
    end

    it 'successfully enqueues a failure notification mailer to send to the veteran' do
      expect(EvidenceSubmission.count).to eq(1)
      expect(EvidenceSubmission.va_notify_email_not_queued.length).to eq(1)
      expect(vanotify_service).to receive(:send_email)
      expect(evidence_submission_failed).to receive(:update).and_call_original
      expect(Rails.logger).to receive(:info).with(message)
      expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags: tags)
      subject.new.perform
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
    end
  end
end
