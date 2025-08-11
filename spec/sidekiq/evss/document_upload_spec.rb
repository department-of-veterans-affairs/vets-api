# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'evss/document_upload'
require 'va_notify/service'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

RSpec.describe EVSS::DocumentUpload, type: :job do
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:user) { create(:user, :loa3) }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:claim_id) { 4567 }
  let(:file_name) { 'doctors-note.pdf' }
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', file_name).read }
  let(:tracked_item_id) { 1234 }
  let(:document_type) { 'L023' }
  let(:document_description) { 'Other Correspondence' }
  let(:document_data) do
    EVSSClaimDocument.new(
      va_eauth_firstName: 'First Name',
      evss_claim_id: claim_id,
      file_name:,
      tracked_item_id:,
      document_type:
    )
  end
  let(:job_id) { '5555' }
  let(:client_stub) { instance_double(EVSS::DocumentsService) }
  let(:issue_instant) { Time.current.to_i }
  let(:current_date_time) { DateTime.current }

  context 'when :cst_send_evidence_submission_failure_emails is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(true)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    # Create Evidence Submission records from factory
    let(:evidence_submission_created) do
      create(:bd_evidence_submission_created,
             tracked_item_id:,
             claim_id:,
             job_id:,
             job_class: described_class)
    end

    context 'when upload succeeds' do
      let(:uploader_stub) { instance_double(EVSSClaimDocumentUploader) }

      it 'there is an evidence submission id, uploads to EVSS' do
        allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
        allow(EVSS::DocumentsService).to receive(:new) { client_stub }
        allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
        allow(uploader_stub).to receive(:read_for_upload) { file }
        expect(uploader_stub).to receive(:remove!).once
        expect(client_stub).to receive(:upload).with(file, document_data)
        allow(EvidenceSubmission).to receive(:find_by).with({ id: evidence_submission_created.id })
                                                      .and_return(evidence_submission_created)
        # Runs all queued jobs of this class
        described_class.new.perform(auth_headers, user.uuid,
                                    document_data.to_serializable_hash, evidence_submission_created.id)
        evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_created.id)
        expect(evidence_submission.upload_status).to eql(BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS])
        expect(evidence_submission.delete_date).not_to be_nil
        expect(StatsD)
          .to have_received(:increment)
          .with('cst.evss.document_uploads.evidence_submission_record_updated.queued')
        expect(Rails.logger)
          .to have_received(:info)
          .with('EVSS - Updated Evidence Submission Record to QUEUED', any_args)
        expect(StatsD)
          .to have_received(:increment)
          .with('cst.evss.document_uploads.evidence_submission_record_updated.success')
        expect(Rails.logger)
          .to have_received(:info)
          .with('EVSS - Updated Evidence Submission Record to SUCCESS', any_args)
      end

      it 'when there is no evidence submission id' do
        allow(EVSS::DocumentUpload).to receive(:update_evidence_submission_for_failure)
        allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
        allow(EVSS::DocumentsService).to receive(:new) { client_stub }
        allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
        allow(uploader_stub).to receive(:read_for_upload) { file }
        expect(uploader_stub).to receive(:remove!).once
        expect(client_stub).to receive(:upload).with(file, document_data)
        allow(EvidenceSubmission).to receive(:find_by)
          .with({ id: nil })
          .and_return(nil)
        # runs all queued jobs of this class
        described_class.new.perform(auth_headers, user.uuid, document_data.to_serializable_hash,
                                    nil)
        expect(EvidenceSubmission.count).to equal(0)
        expect(EVSS::DocumentUpload).not_to have_received(:update_evidence_submission_for_failure)
      end
    end

    context 'when upload fails' do
      let(:error_message) { "#{described_class} failed to update EvidenceSubmission" }
      let(:message) { "#{described_class} EvidenceSubmission updated" }
      let(:tags) { ['service:claim-status', "function: #{error_message}"] }

      context 'when there is an evidence submission record that fails' do
        let(:msg_with_errors) do
          {
            'jid' => job_id,
            'args' => [
              { 'va_eauth_firstName' => 'Bob' },
              user_account_uuid,
              { 'evss_claim_id' => claim_id,
                'tracked_item_id' => tracked_item_id,
                'document_type' => document_type,
                'file_name' => file_name },
              evidence_submission_created.id
            ],
            'created_at' => issue_instant,
            'failed_at' => issue_instant,
            'error_message' => 'An error ',
            'error_class' => 'Faraday::BadRequestError'
          }
        end
        let(:failed_date) do
          BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
        end

        it 'updates an evidence submission record to FAILED' do
          described_class.within_sidekiq_retries_exhausted_block(msg_with_errors) do
            allow(EvidenceSubmission).to receive(:find_by)
              .with({ id: msg_with_errors['args'][3] })
              .and_return(evidence_submission_created)
            allow(EvidenceSubmission).to receive(:update!)
            expect(Rails.logger)
              .to receive(:info)
              .with('EVSS - Updated Evidence Submission Record to FAILED', any_args)
            expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation',
                                                       tags: ['service:claim-status', "function: #{message}"])
          end

          failed_evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_created.id)
          current_personalisation = JSON.parse(failed_evidence_submission.template_metadata)['personalisation']
          expect(failed_evidence_submission.upload_status).to eql(BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
          expect(failed_evidence_submission.error_message).to eql('EVSS::DocumentUpload document upload failure')
          expect(current_personalisation['date_failed']).to eql(failed_date)

          Timecop.freeze(current_date_time) do
            expect(failed_evidence_submission.failed_date).to be_within(1.second).of(current_date_time)
            expect(failed_evidence_submission.acknowledgement_date)
              .to be_within(1.second).of(current_date_time + 30.days)
          end
          Timecop.unfreeze
        end
      end

      context 'does not have an evidence submission id' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_failure_emails).and_return(true)
          allow(EVSS::DocumentUpload).to receive(:update_evidence_submission_for_failure)
          allow(EVSS::DocumentUpload).to receive(:call_failure_notification)
        end

        let(:msg_with_nil_es_id) do
          {
            'jid' => job_id,
            'args' => [
              { 'va_eauth_firstName' => 'Bob' },
              user_account_uuid,
              { 'evss_claim_id' => claim_id,
                'tracked_item_id' => tracked_item_id,
                'document_type' => document_type,
                'file_name' => file_name }
            ],
            'created_at' => issue_instant,
            'failed_at' => issue_instant
          }
        end

        it 'does not update an evidence submission record' do
          described_class.within_sidekiq_retries_exhausted_block(msg_with_nil_es_id) do
            allow(EvidenceSubmission).to receive(:find_by)
              .with({ id: nil })
              .and_return(nil)
          end
          expect(EVSS::DocumentUpload).not_to have_received(:update_evidence_submission_for_failure)
          expect(EVSS::DocumentUpload).to have_received(:call_failure_notification)
          expect(EvidenceSubmission.count).to equal(0)
        end
      end

      context 'when args malformed' do
        let(:msg_args_malformed) do ## added 'test' so file would error
          {
            'jid' => job_id,
            'args' => [
              'test',
              { 'va_eauth_firstName' => 'Bob' },
              user_account_uuid,
              { 'evss_claim_id' => claim_id,
                'tracked_item_id' => tracked_item_id,
                'document_type' => document_type,
                'file_name' => file_name },
              evidence_submission_created.id
            ],
            'created_at' => issue_instant,
            'failed_at' => issue_instant
          }
        end

        it 'fails to create a failed evidence submission record' do
          expect do
            described_class.within_sidekiq_retries_exhausted_block(msg_args_malformed) {}
          end.to raise_error(StandardError, "Missing fields in #{described_class}")
        end
      end

      context 'when error occurs updating evidence submission to FAILED' do
        let(:msg_args) do
          {
            'jid' => job_id,
            'args' => [
              { 'va_eauth_firstName' => 'Bob' },
              user_account_uuid,
              { 'evss_claim_id' => claim_id,
                'tracked_item_id' => tracked_item_id,
                'document_type' => document_type,
                'file_name' => file_name },
              evidence_submission_created.id
            ],
            'created_at' => issue_instant,
            'failed_at' => issue_instant
          }
        end
        let(:log_error_message) { "#{described_class} failed to update EvidenceSubmission" }
        let(:statsd_error_tags) { ['service:claim-status', "function: #{log_error_message}"] }

        before do
          allow_any_instance_of(EvidenceSubmission).to receive(:update!).and_raise(StandardError)
          allow(Rails.logger).to receive(:error)
        end

        it 'error is raised and logged' do
          described_class.within_sidekiq_retries_exhausted_block(msg_args) do
            expect(Rails.logger)
              .to receive(:error)
              .with(log_error_message, { message: 'StandardError' })
            expect(StatsD).to receive(:increment).with('silent_failure',
                                                       tags: statsd_error_tags)
          end
        end
      end

      context 'when evss returns a failure response' do
        it 'raises an error when EVSS returns a failure response' do
          VCR.use_cassette('evss/documents/upload_with_errors') do
            expect do
              described_class.new.perform(user_icn,
                                          document_data.to_serializable_hash,
                                          evidence_submission_created.id)
            end.to raise_error(StandardError)
          end
        end
      end
    end
  end

  context 'when :cst_send_evidence_submission_failure_emails is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(false)
    end

    let(:msg) do
      {
        'jid' => job_id,
        'args' => [{ 'va_eauth_firstName' => 'Bob' },
                   user_account_uuid,
                   { 'evss_claim_id' => claim_id,
                     'tracked_item_id' => tracked_item_id,
                     'document_type' => document_type,
                     'file_name' => file_name }],
        'created_at' => issue_instant,
        'failed_at' => issue_instant
      }
    end

    let(:uploader_stub) { instance_double(EVSSClaimDocumentUploader) }
    let(:formatted_submit_date) do
      BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
    end

    it 'retrieves the file and uploads to EVSS' do
      allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
      allow(EVSS::DocumentsService).to receive(:new) { client_stub }
      file = Rails.root.join('spec', 'fixtures', 'files', file_name).read
      allow(uploader_stub).to receive(:retrieve_from_store!).with(file_name) { file }
      allow(uploader_stub).to receive(:read_for_upload) { file }
      expect(uploader_stub).to receive(:remove!).once
      expect(client_stub).to receive(:upload).with(file, document_data)
      expect(EvidenceSubmission.count).to equal(0)
      described_class.new.perform(auth_headers, user.uuid, document_data.to_serializable_hash, nil)
    end

    context 'when cst_send_evidence_failure_emails is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_failure_emails).and_return(true)
      end

      let(:log_message) { "#{described_class} exhaustion handler email queued" }
      let(:statsd_tags) { ['service:claim-status', 'function: evidence upload to EVSS'] }

      it 'calls EVSS::FailureNotification' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          expect(EVSS::FailureNotification).to receive(:perform_async).with(
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
            .with(log_message)
          expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags: statsd_tags)
        end
      end
    end

    context 'when cst_send_evidence_failure_emails is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_failure_emails).and_return(false)
      end

      it 'does not call EVSS::Failure Notification' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          expect(EVSS::FailureNotification).not_to receive(:perform_async)
        end
      end
    end
  end
end
