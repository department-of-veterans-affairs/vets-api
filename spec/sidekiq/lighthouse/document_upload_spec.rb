# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/document_upload'
require 'va_notify/service'

RSpec.describe Lighthouse::DocumentUpload, type: :job do
  subject { described_class }

  let(:notify_client_stub) { instance_double(VaNotify::Service) }
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
  let(:tags) { subject::DD_ZSF_TAGS }

  before do
    allow(Rails.logger).to receive(:info)
    allow(StatsD).to receive(:increment)
  end

  context 'when cst_send_evidence_failure_emails is enabled' do
    before do
      Flipper.enable(:cst_send_evidence_failure_emails)
    end

    let(:formatted_submit_date) do
      # We want to return all times in EDT
      timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

      # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
      timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    it 'enqueues a failure notification mailer to send to the veteran' do
      allow(VaNotify::Service).to receive(:new) { notify_client_stub }

      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(notify_client_stub).to receive(:send_email).with(
          {
            recipient_identifier: { id_value: user_account.icn, id_type: 'ICN' },
            template_id: 'fake_template_id',
            personalisation: {
              first_name: 'Bob',
              filename: 'docXXXX-XXte.pdf',
              date_submitted: formatted_submit_date,
              date_failed: formatted_submit_date
            }
          }
        )

        expect(Rails.logger)
          .to receive(:info)
          .with('Lighthouse::DocumentUpload exhaustion handler email sent')
        expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags:)
      end
    end
  end

  context 'when cst_send_evidence_failure_emails is disabled' do
    before do
      Flipper.disable(:cst_send_evidence_failure_emails)
    end

    let(:issue_instant) { Time.now.to_i }

    it 'does not enqueue a failure notification mailer to send to the veteran' do
      allow(VaNotify::Service).to receive(:new) { notify_client_stub }

      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(notify_client_stub).not_to receive(:send_email)
      end
    end
  end
end
