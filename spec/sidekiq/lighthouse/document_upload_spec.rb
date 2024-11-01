# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/document_upload'
require 'va_notify/service'

RSpec.describe Lighthouse::DocumentUpload, type: :job do
  subject { described_class }

  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:filename) { 'doctors-note.pdf' }

  let(:issue_instant) { Time.now.to_i }
  let(:args) do
    {
      'args' => [user_account.icn, { 'file_name' => filename, 'first_name' => 'Bob' }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end

  before do
    allow(Rails.logger).to receive(:info)
  end

  context 'when cst_send_evidence_failure_emails is enabled' do
    before do
      Flipper.enable(:cst_send_evidence_failure_emails)
      allow(Lighthouse::FailureNotification).to receive(:perform_async)
    end

    let(:formatted_submit_date) do
      # We want to return all times in EDT
      timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

      # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
      timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    it 'calls Lighthouse::FailureNotification' do
      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(Lighthouse::FailureNotification).to receive(:perform_async).with(
          user_account.icn,
          'Bob', # first_name
          'docXXXX-XXte.pdf', # filename
          formatted_submit_date, # date_submitted
          formatted_submit_date # date_failed
        )

        expect(Rails.logger)
          .to receive(:info)
          .with('Lighthouse::DocumentUpload exhaustion handler email queued')
      end
    end
  end

  context 'when cst_send_evidence_failure_emails is disabled' do
    before do
      Flipper.disable(:cst_send_evidence_failure_emails)
    end

    let(:issue_instant) { Time.now.to_i }

    it 'does not call Lighthouse::Failure Notification' do
      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(Lighthouse::FailureNotification).not_to receive(:perform_async)
      end
    end
  end
end
