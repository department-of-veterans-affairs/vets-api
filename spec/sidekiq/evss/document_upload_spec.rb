# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'evss/document_upload'
require 'va_notify/service'
require 'lighthouse/benefits_documents/constants'

RSpec.describe EVSS::DocumentUpload, type: :job do
  subject(:job) do
    described_class.perform_async(auth_headers,
                                  user.uuid,
                                  document_data.to_serializable_hash)
  end

  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:claim_id) { 4567 }
  let(:file_name) { 'doctors-note.pdf' }
  let(:tracked_item_id) { 1234 }
  let(:document_type) { 'L023' }
  let(:document_data) do
    EVSSClaimDocument.new(
      va_eauth_firstName: 'First Name',
      evss_claim_id: claim_id,
      file_name:,
      tracked_item_id:,
      document_type:
    )
  end
  let(:job_class) { 'EVSS::DocumentUpload' }
  let(:job_id) { job }

  let(:client_stub) { instance_double('EVSS::DocumentsService') }
  let(:notify_client_stub) { instance_double(VaNotify::Service) }
  let(:issue_instant) { Time.now.to_i }
  let(:msg) do
    {
      'jid' => job_id,
      'args' => [{ 'va_eauth_firstName' => 'Bob' }, user_account_uuid,
                 { 'evss_claim_id' => claim_id,
                   'tracked_item_id' => tracked_item_id,
                   'document_type' => document_type,
                   'file_name' => file_name }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end
  let(:msg_with_errors) do ## added 'test' so file would error
    {
      'jid' => job_id,
      'args' => ['test', { 'va_eauth_firstName' => 'Bob' }, user_account_uuid,
                 { 'evss_claim_id' => claim_id,
                   'tracked_item_id' => tracked_item_id,
                   'document_type' => document_type,
                   'file_name' => file_name }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end

  let(:log_message) { "#{job_class} exhaustion handler email queued" }
  let(:log_error_message) { "#{job_class} failed to update EvidenceSubmission" }
  let(:statsd_tags) { ['service:claim-status', 'function: evidence upload to EVSS'] }
  let(:statsd_error_tags) { ['service:claim-status', "function: #{log_error_message}"] }

  context 'when :cst_send_evidence_submission_failure_emails is enabled' do
    before { Flipper.enable(:cst_send_evidence_submission_failure_emails) }

    context 'when upload succeeds' do
      let(:uploader_stub) { instance_double('EVSSClaimDocumentUploader') }
      let(:file) { Rails.root.join('spec', 'fixtures', 'files', file_name).read }
      let(:formatted_submit_date) do
        # We want to return all times in EDT
        timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

        # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
        timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
      end
      let(:evidence_submission_pending) do
        create(:bd_evidence_submission_pending,
               tracked_item_id:,
               claim_id:,
               job_id:,
               job_class: described_class)
      end

      it 'retrieves the file and uploads to EVSS' do
        allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
        allow(EVSS::DocumentsService).to receive(:new) { client_stub }
        allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
        allow(uploader_stub).to receive(:read_for_upload) { file }
        expect(uploader_stub).to receive(:remove!).once
        expect(client_stub).to receive(:upload).with(file, document_data)
        allow(EvidenceSubmission).to receive(:find_by).with({ job_id: job_id.to_s })
                                                      .and_return(evidence_submission_pending)
        described_class.drain
      end
    end

    context 'when upload fails' do
      let(:evidence_submission_failed) { create(:bd_evidence_submission_failed) }
      let!(:evidence_submission_pending) do
        create(:bd_evidence_submission_pending,
               tracked_item_id:,
               claim_id:,
               job_id:,
               job_class: described_class)
      end

      it 'updates an evidence submission record with a FAILED status' do
        EVSS::DocumentUpload.within_sidekiq_retries_exhausted_block(msg) {}
        expect(EvidenceSubmission.va_notify_email_not_queued.length).to equal(1)
      end

      it 'fails to create a failed evidence submission record when args malformed' do
        expect do
          described_class.within_sidekiq_retries_exhausted_block(msg_with_errors) {}
        end.to raise_error(StandardError, "Missing fields in #{job_class}")
      end
    end
  end

  context 'when :cst_send_evidence_submission_failure_emails is disabled' do
    before { Flipper.disable(:cst_send_evidence_submission_failure_emails) }

    let(:uploader_stub) { instance_double('EVSSClaimDocumentUploader') }
    let(:formatted_submit_date) do
      # We want to return all times in EDT
      timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

      # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
      timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    it 'retrieves the file and uploads to EVSS' do
      allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
      allow(EVSS::DocumentsService).to receive(:new) { client_stub }
      file = File.read("#{::Rails.root}/spec/fixtures/files/#{file_name}")
      allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
      allow(uploader_stub).to receive(:read_for_upload) { file }
      expect(uploader_stub).to receive(:remove!).once
      expect(client_stub).to receive(:upload).with(file, document_data)
      expect(EvidenceSubmission.count).to equal(0)
      described_class.new.perform(auth_headers, user.uuid, document_data.to_serializable_hash)
    end

    context 'when cst_send_evidence_failure_emails is enabled' do
      before do
        Flipper.enable(:cst_send_evidence_failure_emails)
      end

      it 'calls EVSS::FailureNotification' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          expect(EVSS::FailureNotification).to receive(:perform_async).with(
            user_account.icn,
            personalisation: {
              first_name: 'Bob',
              document_type: document_type,
              file_name: file_name,
              date_submitted: formatted_submit_date,
              date_failed: formatted_submit_date
            }
          )

          expect(Rails.logger)
            .to receive(:info)
            .with(log_message)
          expect(StatsD).to receive(:increment).with('silent_failure', tags: statsd_tags)
        end
      end
    end

    context 'when cst_send_evidence_failure_emails is disabled' do
      before do
        Flipper.disable(:cst_send_evidence_failure_emails)
      end

      it 'does not call EVSS::Failure Notification' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          expect(EVSS::FailureNotification).not_to receive(:perform_async)
        end
      end
    end
  end
end
