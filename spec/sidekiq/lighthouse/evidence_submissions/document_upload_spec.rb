# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'lighthouse/evidence_submissions/document_upload'
require 'va_notify/service'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

RSpec.describe Lighthouse::EvidenceSubmissions::DocumentUpload, type: :job do
  # subject(:job) do
  #   described_class.perform_async(user_icn,
  #                                 document_data.to_serializable_hash)
  # end

  let(:user_icn) { user_account.icn }
  let(:claim_id) { 4567 }
  let(:file_name) { 'doctors-note.pdf' }
  let(:tracked_item_ids) { 1234 }
  let(:document_type) { 'L029' }
  let(:document_description) { 'Copy of a DD214' }
  let(:document_data) do
    LighthouseDocument.new(
      first_name: 'First Name',
      participant_id: '1111',
      claim_id:,
      uuid: SecureRandom.uuid,
      file_extension: 'pdf',
      file_name:,
      tracked_item_id: tracked_item_ids,
      document_type:
    )
  end
  let(:user_account) { create(:user_account) }
  let(:job_id) { '1234' }
  let(:client_stub) { instance_double(BenefitsDocuments::WorkerService) }
  let(:job_class) { 'Lighthouse::EvidenceSubmissions::DocumentUpload' }
  let(:issue_instant) { Time.now.to_i }
  let(:current_date_time) { DateTime.now.utc }
  let(:msg) do
    {
      'jid' => job_id,
      'args' => [user_account.icn,
                 { 'first_name' => 'Bob',
                   'claim_id' => claim_id,
                   'document_type' => document_type,
                   'file_name' => file_name,
                   'tracked_item_id' => tracked_item_ids }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', file_name).read }
  let(:formatted_submit_date) do
    BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
  end

  # Create Evidence Submission records from factory
  let(:evidence_submission_failed) do
    create(:bd_lh_evidence_submission_failed_type1_error)
  end
  let(:evidence_submission_created) do
    create(:bd_evidence_submission_created,
           tracked_item_id: tracked_item_ids,
           claim_id:,
           job_id:,
           job_class: described_class)
  end

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body:)
  end

  context 'when :cst_send_evidence_submission_failure_emails is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(true)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    context 'when upload succeeds' do
      let(:uploader_stub) { instance_double(LighthouseDocumentUploader) }
      let(:message) { "#{job_class} EvidenceSubmission updated" }
      let(:success_response) do
        mock_response(
          status: 200,
          body: {
            'data' => {
              'success' => true,
              'requestId' => 1234
            }
          }
        )
      end
      let(:failed_date) do
        BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
      end

      it 'there is an evidence submission id, uploads to Lighthouse and returns a success response' do
        allow(LighthouseDocumentUploader).to receive(:new) { uploader_stub }
        allow(BenefitsDocuments::WorkerService).to receive(:new) { client_stub }
        allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
        allow(uploader_stub).to receive(:read_for_upload) { file }
        expect(uploader_stub).to receive(:remove!).once
        expect(client_stub).to receive(:upload_document).with(file, document_data).and_return(success_response)
        allow(EvidenceSubmission).to receive(:find_by)
          .with({ id: evidence_submission_created.id })
          .and_return(evidence_submission_created)
        # Runs all queued jobs of this class
        described_class.new.perform(user_icn,
                                    document_data.to_serializable_hash,
                                    evidence_submission_created.id)
        # After running DocumentUpload job, there should be an updated EvidenceSubmission record
        # with the response request_id
        new_evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_created.id)
        expect(new_evidence_submission.request_id).to eql(success_response.body.dig('data', 'requestId'))
        expect(new_evidence_submission.upload_status).to eql(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
        expect(StatsD)
          .to have_received(:increment)
          .with('cst.lighthouse.document_uploads.evidence_submission_record_updated.queued')
        expect(Rails.logger)
          .to have_received(:info)
          .with('LH - Updated Evidence Submission Record to QUEUED', any_args)
        expect(StatsD)
          .to have_received(:increment)
          .with('cst.lighthouse.document_uploads.evidence_submission_record_updated.added_request_id')
        expect(Rails.logger)
          .to have_received(:info)
          .with('LH - Updated Evidence Submission Record to PENDING', any_args)
      end

      it 'there is no evidence submission id' do
        allow(LighthouseDocumentUploader).to receive(:new) { uploader_stub }
        allow(BenefitsDocuments::WorkerService).to receive(:new) { client_stub }
        allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
        allow(uploader_stub).to receive(:read_for_upload) { file }
        expect(uploader_stub).to receive(:remove!).once
        expect(client_stub).to receive(:upload_document).with(file, document_data).and_return(success_response)
        allow(EvidenceSubmission).to receive(:find_by)
          .with({ id: nil })
          .and_return(nil)
        # runs all queued jobs of this class
        described_class.new.perform(user_icn,
                                    document_data.to_serializable_hash,
                                    nil)
      end
    end

    context 'when upload fails' do
      let(:failure_response) do
        {
          data: {
            success: false
          }
        }
      end
      let(:error_message) { "#{job_class} failed to create EvidenceSubmission" }
      let(:tags) { ['service:claim-status', "function: #{error_message}"] }
      let(:failed_date) do
        BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
      end

      context 'when there is an evidence submission record that errors' do
        let(:msg_with_errors) do ## added 'test' so file would error
          {
            'jid' => job_id,
            'args' => [user_account.icn,
                       { 'first_name' => 'Bob',
                         'claim_id' => claim_id,
                         'document_type' => document_type,
                         'file_name' => file_name,
                         'tracked_item_id' => tracked_item_ids },
                       evidence_submission_created.id],
            'created_at' => issue_instant,
            'failed_at' => issue_instant,
            'error_message' => error_message,
            'error_class' => 'Faraday::BadRequestError'
          }
        end

        it 'updates an evidence submission record to FAILED' do
          described_class.within_sidekiq_retries_exhausted_block(msg_with_errors) do
            allow(EvidenceSubmission).to receive(:find_by)
              .with({ id: evidence_submission_created.id })
              .and_return(evidence_submission_created)
            # expect(described_class).to receive(:perform_async).with(
            #   user_account.icn,
            #   {
            #     first_name: 'Bob',
            #     document_type: document_description,
            #     filename: BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(file_name),
            #     date_submitted: formatted_submit_date,
            #     date_failed: formatted_submit_date
            #   },
            #   evidence_submission_created.id
            # )
            allow(described_class).to receive(:update_evidence_submission_for_failure)
            expect(described_class).to receive(:update_evidence_submission_for_failure)
              .with(evidence_submission_created, msg_with_errors)
            # allow(EvidenceSubmission).to receive(:update!)
            # expect(EvidenceSubmission).to receive(:update!)
            # allow(evidence_submission_created).to receive(:update_evidence_submission_for_failure)
            # expect(evidence_submission_created).to receive(:update_evidence_submission_for_failure)
            # expect(Rails.logger)
            #   .to have_received(:info)
            #   .with('LH - Updated Evidence Submission Record to FAILED', any_args)
            # expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation',
            #                                            tags: ['service:claim-status', "function: #{message}"])
          end

          failed_evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_created.id)
          byebug
          current_personalisation = JSON.parse(failed_evidence_submission.template_metadata)['personalisation']
          expect(failed_evidence_submission.upload_status).to eql(BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
          expect(failed_evidence_submission.error_message)
            .to eql('Lighthouse::EvidenceSubmissions::DocumentUpload document upload failure')
          expect(current_personalisation['date_failed']).to eql(failed_date)

          Timecop.freeze(current_date_time) do
            expect(failed_evidence_submission.failed_date).to be_within(1.second).of(current_date_time)
            expect(failed_evidence_submission.acknowledgement_date)
              .to be_within(1.second).of((current_date_time + 30.days))
          end
          Timecop.unfreeze
        end
      end

      it 'does not have an evidence submission record' do
        allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_failure_emails).and_return(true)
        allow(described_class).to receive(:update_evidence_submission_for_failure)
        Lighthouse::EvidenceSubmissions::DocumentUpload.within_sidekiq_retries_exhausted_block(msg) do
          allow(EvidenceSubmission).to receive(:find_by)
            .with({ id: nil })
            .and_return(nil)
          expect(Lighthouse::FailureNotification).to receive(:perform_async).with(
            user_account.icn,
            {
              first_name: 'Bob',
              document_type: document_description,
              filename: BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(file_name),
              date_submitted: formatted_submit_date,
              date_failed: formatted_submit_date
            }
          )
          expect(described_class).not_to receive(:update_evidence_submission_for_failure)
          expect(EvidenceSubmission.count).to equal(0)
        end
      end

      context 'when args malformed' do
        let(:msg_with_errors) do ## added 'test' so file would error
          {
            'jid' => job_id,
            'args' => ['test',
                       user_account.icn,
                       { 'first_name' => 'Bob',
                         'claim_id' => claim_id,
                         'document_type' => document_type,
                         'file_name' => file_name,
                         'tracked_item_id' => tracked_item_ids },
                       evidence_submission_created.id],
            'created_at' => issue_instant,
            'failed_at' => issue_instant
          }
        end

        it 'fails to create a failed evidence submission record' do
          expect do
            described_class.within_sidekiq_retries_exhausted_block(msg_with_errors) {}
          end.to raise_error(StandardError, "Missing fields in #{job_class}")
        end
      end

      it 'raises an error when Lighthouse returns a failure response' do
        allow(client_stub).to receive(:upload_document).with(file, document_data).and_return(failure_response)
        expect do
          described_class.new.perform(user_icn,
                                      document_data.to_serializable_hash,
                                      evidence_submission_created.id)
        end.to raise_error(StandardError)
      end
    end
  end

  context 'when :cst_send_evidence_submission_failure_emails is disabled' do
    before do
      allow(Lighthouse::FailureNotification).to receive(:perform_async)
      allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(false)
    end

    let(:uploader_stub) { instance_double(LighthouseDocumentUploader) }
    let(:tags) { ['service:claim-status', 'function: evidence upload to Lighthouse'] }

    it 'retrieves the file, uploads to Lighthouse and returns a success response' do
      allow(LighthouseDocumentUploader).to receive(:new) { uploader_stub }
      allow(BenefitsDocuments::WorkerService).to receive(:new) { client_stub }
      allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
      allow(uploader_stub).to receive(:read_for_upload) { file }
      expect(uploader_stub).to receive(:remove!).once
      expect(client_stub).to receive(:upload_document).with(file, document_data)
      expect(EvidenceSubmission.count).to equal(0)
      described_class.new.perform(user_icn,
                                  document_data.to_serializable_hash,
                                  evidence_submission_created.id)
    end

    context 'when cst_send_evidence_failure_emails is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_failure_emails).and_return(true)
      end

      it 'calls Lighthouse::FailureNotification' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          expect(Lighthouse::FailureNotification).to receive(:perform_async).with(
            user_account.icn,
            {
              first_name: 'Bob',
              document_type: document_description,
              filename: BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(file_name),
              date_submitted: formatted_submit_date,
              date_failed: formatted_submit_date
            }
          )
          expect(EvidenceSubmission.count).to equal(0)
          expect(Rails.logger)
            .to receive(:info)
            .with("#{job_class} exhaustion handler email queued")
          expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags:)
        end
      end
    end
  end
end
