# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/benefits_documents/failure_notification_email_job'
require 'va_notify/service'

RSpec.describe BenefitsDocuments::FailureNotificationEmailJob, type: :job do
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
  end

  # context 'when there are no FAILED records' do
  #   it 'doesnt send anything' do
  #     expect(EvidenceSubmission).not_to receive(:update)
  #     expect(EvidenceSubmission.va_notify_email_sent.length).to equal(0)
  #   end
  # end

  context 'when there is a FAILED record with a va_notify_date' do
    before do
      allow(EvidenceSubmission).to receive(:va_notify_email_not_sent)
      create(:bd_evidence_submission_failed_va_notify_email_sent)
    end

    it 'doesnt update an evidence submission record' do
      expect(EvidenceSubmission.va_notify_email_sent.length).to equal(1)

      subject.new.perform
      expect(EvidenceSubmission).not_to receive(:update)

      # This is 1 since is has already been sent
      expect(EvidenceSubmission.va_notify_email_sent.length).to equal(1)
    end
  end

  context 'when there is 1 FAILED record without a va_notify_date' do
    before do
      allow(EvidenceSubmission).to receive(:va_notify_email_not_sent).and_return([evidence_submission_failed])
      allow(EvidenceSubmission).to receive(:update)
    end

    let!(:evidence_submission_failed) { create(:bd_evidence_submission_failed) }

    it 'successfully enqueues a failure notification mailer to send to the veteran' do
      expect(EvidenceSubmission.va_notify_email_sent.length).to equal(0)

      subject.new.perform
      # expect(EvidenceSubmission).to receive(:va_notify_email_not_sent).and_return(evidence_submission_failed)
      expect(EvidenceSubmission).to receive(:update)
      expect(EvidenceSubmission.va_notify_email_sent.length).to equal(1)
    end
  end
end
