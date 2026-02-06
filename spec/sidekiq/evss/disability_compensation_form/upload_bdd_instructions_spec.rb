# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::UploadBddInstructions, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_use_api_provider_for_bdd_instructions) # rubocop:disable Project/ForbidFlipperToggleInSpecs
  end

  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           submitted_claim_id: '600130094')
  end
  let(:file_read) { File.read('lib/evss/disability_compensation_form/bdd_instructions.pdf') }

  describe 'perform' do
    let(:client) { double(:client) }
    let(:document_data) { double(:document_data) }

    before do
      allow(EVSS::DocumentsService)
        .to receive(:new)
        .and_return(client)
    end

    context 'when file_data exists' do
      it 'calls the documents service api with file body and document data' do
        expect(EVSSClaimDocument)
          .to receive(:new)
          .with(
            evss_claim_id: submission.submitted_claim_id,
            file_name: 'BDD_Instructions.pdf',
            tracked_item_id: nil,
            document_type: 'L023'
          )
          .and_return(document_data)

        subject.perform_async(submission.id)
        expect(client).to receive(:upload).with(file_read, document_data)
        described_class.drain
      end

      context 'with a timeout' do
        it 'logs a retryable error and re-raises the original error' do
          allow(client).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
          subject.perform_async(submission.id)
          expect(Form526JobStatus).to receive(:upsert).twice
          expect { described_class.drain }.to raise_error(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        end
      end
    end
  end

  describe 'When an ApiProvider is used for uploads' do
    before do
      Flipper.enable(:disability_compensation_use_api_provider_for_bdd_instructions) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      # StatsD metrics are incremented in several callbacks we're not testing here so we need to allow them
      allow(StatsD).to receive(:increment)
    end

    let(:perform_upload) do
      subject.perform_async(submission.id)
      described_class.drain
    end

    context 'when the disability_compensation_upload_bdd_instructions_to_lighthouse flipper is enabled' do
      let(:faraday_response) { instance_double(Faraday::Response) }
      let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }
      let(:expected_statsd_metrics_prefix) do
        'worker.evss.submit_form526_bdd_instructions.lighthouse_supplemental_document_upload_provider'
      end

      let(:expected_lighthouse_document) do
        LighthouseDocument.new(
          claim_id: submission.submitted_claim_id,
          participant_id: submission.auth_headers['va_eauth_pid'],
          document_type: 'L023',
          file_name: 'BDD_Instructions.pdf'
        )
      end

      before do
        Flipper.enable(:disability_compensation_upload_bdd_instructions_to_lighthouse) # rubocop:disable Project/ForbidFlipperToggleInSpecs

        allow(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
          .and_return(faraday_response)

        allow(faraday_response).to receive(:body).and_return(
          {
            'data' => {
              'success' => true,
              'requestId' => lighthouse_request_id
            }
          }
        )
      end

      it 'uploads a BDD Instruction PDF to Lighthouse' do
        expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
          .with(file_read, expected_lighthouse_document)
        perform_upload
      end

      it 'logs the upload attempt with the correct job prefix' do
        expect(StatsD).to receive(:increment).with(
          "#{expected_statsd_metrics_prefix}.upload_attempt"
        )
        perform_upload
      end

      it 'increments the correct StatsD success metric' do
        expect(StatsD).to receive(:increment).with(
          "#{expected_statsd_metrics_prefix}.upload_success"
        )
        perform_upload
      end

      it 'creates a pending Lighthouse526DocumentUpload record for the submission so we can poll Lighthouse later' do
        upload_attributes = {
          aasm_state: 'pending',
          form526_submission_id: submission.id,
          document_type: 'BDD Instructions',
          lighthouse_document_request_id: lighthouse_request_id
        }

        expect(Lighthouse526DocumentUpload.where(**upload_attributes).count).to eq(0)

        perform_upload

        expect(Lighthouse526DocumentUpload.where(**upload_attributes).count).to eq(1)
      end

      context 'when Lighthouse returns an error response' do
        let(:exception_errors) { [{ detail: 'Something Broke' }] }

        before do
          # Skip additional logging that occurs in Lighthouse::ServiceException handling
          allow(Rails.logger).to receive(:error)

          allow(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
            .and_raise(Common::Exceptions::BadRequest.new(errors: exception_errors))
        end

        it 'logs the Lighthouse error response and re-raises the error' do
          expect(Rails.logger).to receive(:error).with(
            'LighthouseSupplementalDocumentUploadProvider upload failed',
            {
              class: 'LighthouseSupplementalDocumentUploadProvider',
              submitted_claim_id: submission.submitted_claim_id,
              submission_id: submission.id,
              user_uuid: submission.user_uuid,
              va_document_type_code: 'L023',
              primary_form: 'Form526',
              error_info: exception_errors
            }
          )

          expect { perform_upload }.to raise_error(Common::Exceptions::BadRequest)
        end

        it 'increments the correct status failure metric and re-raises the error' do
          expect(StatsD).to receive(:increment).with(
            "#{expected_statsd_metrics_prefix}.upload_failure"
          )

          expect { perform_upload }.to raise_error(Common::Exceptions::BadRequest)
        end
      end
    end

    # Upload to EVSS
    context 'when the disability_compensation_upload_bdd_instructions_to_lighthouse flipper is disabled' do
      before do
        Flipper.disable(:disability_compensation_upload_bdd_instructions_to_lighthouse) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
      end

      let(:evss_claim_document) do
        EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          document_type: 'L023',
          file_name: 'BDD_Instructions.pdf'
        )
      end

      let(:expected_statsd_metrics_prefix) do
        'worker.evss.submit_form526_bdd_instructions.evss_supplemental_document_upload_provider'
      end

      it 'uploads the document via the EVSS Documents Service' do
        expect_any_instance_of(EVSS::DocumentsService).to receive(:upload)
          .with(file_read, evss_claim_document)

        perform_upload
      end

      it 'logs the upload attempt with the correct job prefix' do
        expect(StatsD).to receive(:increment).with(
          "#{expected_statsd_metrics_prefix}.upload_attempt"
        )

        perform_upload
      end

      it 'increments the correct StatsD success metric' do
        expect(StatsD).to receive(:increment).with(
          "#{expected_statsd_metrics_prefix}.upload_success"
        )

        perform_upload
      end

      context 'when an upload raises an EVSS response error' do
        it 'logs an upload error' do
          allow_any_instance_of(EVSS::DocumentsService).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSError)
          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_upload_failure)

          expect do
            subject.perform_async(submission.id)
            described_class.drain
          end.to raise_error(EVSS::ErrorMiddleware::EVSSError)
        end
      end
    end
  end

  context 'catastrophic failure state' do
    describe 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission) }
      let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }

      it 'updates a StatsD counter and updates the status on an exhaustion event' do
        subject.within_sidekiq_retries_exhausted_block({ 'jid' => form526_job_status.job_id }) do
          expect(StatsD).to receive(:increment).with("#{subject::STATSD_KEY_PREFIX}.exhausted")
          expect(Rails).to receive(:logger).and_call_original
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end

      context 'when the API Provider uploads are enabled' do
        before do
          Flipper.enable(:disability_compensation_use_api_provider_for_bdd_instructions) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        let(:sidekiq_job_exhaustion_errors) do
          {
            'jid' => form526_job_status.job_id,
            'error_class' => 'Broken Job Error',
            'error_message' => 'Your Job Broke',
            'args' => [form526_submission.id]
          }
        end

        context 'for a Lighthouse upload' do
          it 'logs the job failure' do
            Flipper.enable(:disability_compensation_upload_bdd_instructions_to_lighthouse) # rubocop:disable Project/ForbidFlipperToggleInSpecs

            subject.within_sidekiq_retries_exhausted_block(sidekiq_job_exhaustion_errors) do
              expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
                .to receive(:log_uploading_job_failure)
                .with(EVSS::DisabilityCompensationForm::UploadBddInstructions, 'Broken Job Error', 'Your Job Broke')
            end
          end
        end

        context 'for an EVSS Upload' do
          it 'logs the job failure' do
            Flipper.disable(:disability_compensation_upload_bdd_instructions_to_lighthouse) # rubocop:disable Project/ForbidFlipperToggleInSpecs

            subject.within_sidekiq_retries_exhausted_block(sidekiq_job_exhaustion_errors) do
              expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_uploading_job_failure)
                .with(EVSS::DisabilityCompensationForm::UploadBddInstructions, 'Broken Job Error', 'Your Job Broke')
            end
          end
        end
      end
    end
  end
end
