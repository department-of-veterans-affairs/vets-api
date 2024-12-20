# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'evss/document_upload'
require 'va_notify/service'

RSpec.describe EVSS::DocumentUpload, type: :job do
  subject(:job) do
    described_class.perform_async(auth_headers, user.uuid, document_data.to_serializable_hash)
  end

  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:claim_id) { '4567' }
  let(:filename) { 'doctors-note.pdf' }
  let(:tracked_item_id) { '1234' }
  let(:document_type) { 'L023' }
  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: claim_id,
      file_name: filename,
      tracked_item_id:,
      document_type:
    )
  end
  let(:job_id) { job }

  let(:client_stub) { instance_double('EVSS::DocumentsService') }
  let(:notify_client_stub) { instance_double(VaNotify::Service) }

  context 'when upload succeeds' do
    let(:uploader_stub) { instance_double('EVSSClaimDocumentUploader') }
    let(:file) { Rails.root.join('spec', 'fixtures', 'files', filename).read }

    it 'retrieves the file and uploads to EVSS' do
      allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
      allow(EVSS::DocumentsService).to receive(:new) { client_stub }
      allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
      allow(uploader_stub).to receive(:read_for_upload) { file }
      expect(uploader_stub).to receive(:remove!).once
      expect(client_stub).to receive(:upload).with(file, document_data)
      described_class.new.perform(auth_headers, user.uuid, document_data.to_serializable_hash)
    end
  end

  context 'when upload fails' do
    let(:issue_instant) { Time.now.to_i }
    let(:msg) do
      {
        'args' => [{ 'va_eauth_firstName' => 'Bob' }, user_account_uuid, { 'file_name' => filename }],
        'created_at' => issue_instant,
        'failed_at' => issue_instant
      }
    end
    let(:msg_with_errors) do
      {
        'args' => [{ 'va_eauth_firstName' => 'Bob' }, 'test', user_account_uuid, { 'file_name' => filename }],
        'created_at' => issue_instant,
        'failed_at' => issue_instant
      }
    end
    let(:evidence_submission_failed) { create(:bd_evidence_submission_failed) }
    let(:job_class) { 'EVSS::DocumentUpload' }
    let(:error_message) { "#{job_class} failed to create EvidenceSubmission" }
    let(:tags) { ['service:claim-status', "function: #{error_message}"] }

    it 'creates a failed evidence submission record' do
      EVSS::DocumentUpload.within_sidekiq_retries_exhausted_block(msg) do
        expect(EvidenceSubmission).to receive(:create).and_return(evidence_submission_failed)
      end
      expect(EvidenceSubmission.va_notify_email_not_queued.length).to equal(1)
    end

    it 'fails to create a failed evidence submission record when args malformed' do
      EVSS::DocumentUpload.within_sidekiq_retries_exhausted_block(msg_with_errors) do
        expect(EvidenceSubmission).not_to receive(:create)
        expect(Rails.logger)
          .to receive(:info)
          .with(error_message, { messsage: "undefined method `[]' for nil" })
        expect(StatsD).to receive(:increment).with('silent_failure', tags: tags)
      end
    end
  end
end
