# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'lighthouse/benefits_documents/document_upload'
require 'va_notify/service'
require 'lighthouse/benefits_documents/constants'

RSpec.describe Lighthouse::BenefitsDocuments::DocumentUpload, type: :job do
  subject(:job) do
    described_class.perform_async(user_icn,
                                  document_data.to_serializable_hash,
                                  user_account_uuid, claim_id,
                                  tracked_item_ids)
  end

  let(:user_icn) { user_account.icn }
  let(:claim_id) { '4567' }
  let(:filename) { 'doctors-note.pdf' }
  let(:tracked_item_ids) { '1234' }
  let(:document_type) { 'L029' }
  let(:document_data) do
    LighthouseDocument.new(
      first_name: 'First Name',
      participant_id: '1111',
      claim_id: claim_id,
      # file_obj: file,
      uuid: SecureRandom.uuid,
      file_extension: 'pdf',
      file_name: filename,
      tracked_item_id: tracked_item_ids,
      document_type:
    )
  end
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:job_id) { job }

  let(:client_stub) { instance_double(BenefitsDocuments::WorkerService) }
  let(:job_class) { 'Lighthouse::BenefitsDocuments::DocumentUpload' }
  let(:msg) do
    {
      'args' => [user_account.icn, { 'file_name' => filename, 'first_name' => 'Bob' }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', filename).read }

  context 'when upload succeeds' do
    let(:uploader_stub) { instance_double(LighthouseDocumentUploader) }
    let(:evidence_submission_pending) do
      create(:bd_evidence_submission_pending,
             tracked_item_id: tracked_item_ids,
             claim_id:,
             job_id:,
             job_class: described_class)
    end
    let(:response) do
      {
        data: {
          success: true,
          requestId: '12345678'
        }
      }
    end

    it 'retrieves the file and uploads to Lighthouse' do
      allow(LighthouseDocumentUploader).to receive(:new) { uploader_stub }
      allow(BenefitsDocuments::WorkerService).to receive(:new) { client_stub }
      allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
      allow(uploader_stub).to receive(:read_for_upload) { file }
      allow(client_stub).to receive(:upload_document).with(file, document_data)
      expect(uploader_stub).to receive(:remove!).once
      expect(client_stub).to receive(:upload_document).with(file, document_data).and_return(response)
      allow(EvidenceSubmission).to receive(:find_or_create_by)
        .with({ claim_id:,
                tracked_item_id: tracked_item_ids,
                job_id:,
                job_class:,
                upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING] })
        .and_return(evidence_submission_pending)
      described_class.drain # runs all queued jobs of this class
      # After running DocumentUpload job, there should be a new EvidenceSubmission record
      # with the response request_id
      expect(EvidenceSubmission.find_by(job_id: job_id).request_id).to eql(response.dig(:data, :requestId))
    end
  end

  context 'when upload fails' do
    let(:issue_instant) { Time.now.to_i }
    let(:msg_with_errors) do
      {
        'args' => ['test', user_account.icn, { 'file_name' => filename, 'first_name' => 'Bob' }],
        'created_at' => issue_instant,
        'failed_at' => issue_instant
      }
    end
    let(:failure_response) do
      {
        data: {
          success: false
        }
      }
    end
    let(:evidence_submission_failed) { create(:bd_evidence_submission_failed) }
    let(:error_message) { "#{job_class} failed to create EvidenceSubmission" }
    let(:tags) { ['service:claim-status', "function: #{error_message}"] }

    it 'creates a failed evidence submission record' do
      Lighthouse::BenefitsDocuments::DocumentUpload.within_sidekiq_retries_exhausted_block(msg) do
        expect(EvidenceSubmission).to receive(:create).and_return(evidence_submission_failed)
      end
      expect(EvidenceSubmission.va_notify_email_not_queued.length).to equal(1)
    end

    it 'fails to create a failed evidence submission record when args malformed' do
      Lighthouse::BenefitsDocuments::DocumentUpload.within_sidekiq_retries_exhausted_block(msg_with_errors) do
        expect(EvidenceSubmission).not_to receive(:create)
        expect(Rails.logger)
          .to receive(:info)
          .with(error_message, { messsage: "undefined method `[]' for nil" })
        expect(StatsD).to receive(:increment).with('silent_failure', tags: tags)
      end
    end

    it 'raises an error when Lighthouse returns a failure response' do
      allow(client_stub).to receive(:upload_document).with(file, document_data).and_return(failure_response)
      expect do
        job
        described_class.drain
      end.to raise_error(StandardError)
    end
  end
end
