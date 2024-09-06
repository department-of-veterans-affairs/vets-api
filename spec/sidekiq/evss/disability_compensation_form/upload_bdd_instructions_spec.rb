# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::UploadBddInstructions, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_use_api_provider_for_bdd_instructions)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           submitted_claim_id: '600130094')
  end

  describe 'perform' do
    let(:client) { double(:client) }
    let(:document_data) { double(:document_data) }
    let(:file_read) { File.read('lib/evss/disability_compensation_form/bdd_instructions.pdf') }

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

    context 'when the disability_compensation_use_api_provider_for_bdd_instructions flipper is enabled' do
      before do
        Flipper.enable(:disability_compensation_use_api_provider_for_bdd_instructions)
      end

      context 'when the ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS feature flag is enabled' do
        let(:faraday_response) { instance_double(Faraday::Response) }
        let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }

        before do
          Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS)

          allow_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:submit_upload_document)
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

        it 'uploads the document via the LighthouseSupplementalDocumentUploadProvider' do
          lighthouse_document = instance_double(LighthouseDocument)

          allow_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:generate_upload_document)
            .and_return(lighthouse_document)

          expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:submit_upload_document).with(
            lighthouse_document,
            file_read
          )

          subject.perform_async(submission.id)
          described_class.drain
        end

        it 'logs an upload success via the upload provider' do
          expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
            .to receive(:log_upload_success).with('worker.evss.submit_form526_bdd_instructions')

          subject.perform_async(submission.id)
          described_class.drain
        end

        it 'creates a pending Lighthouse526DocumentUpload record for the submission so we can poll Lighthouse later' do
          upload_attributes = {
            aasm_state: 'pending',
            form526_submission_id: submission.id,
            document_type: Lighthouse526DocumentUpload::BDD_INSTRUCTIONS_DOCUMENT_TYPE,
            lighthouse_document_request_id: lighthouse_request_id
          }

          expect do
            subject.perform_async(submission.id)
            described_class.drain
          end.to change { Lighthouse526DocumentUpload.where(**upload_attributes).count }.by(1)
        end
      end

      context 'when the ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS feature flag is disabled' do
        before do
          Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS)
        end

        it 'uploads the document via the EVSSSupplementalDocumentUploadProvider' do
          evss_claim_document = instance_double(EVSSClaimDocument)

          allow_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:generate_upload_document)
            .and_return(evss_claim_document)

          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:submit_upload_document).with(
            evss_claim_document,
            file_read
          )

          subject.perform_async(submission.id)
          described_class.drain
        end

        it 'logs an upload success' do
          # Stub API call
          allow_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:submit_upload_document)
          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider)
            .to receive(:log_upload_success).with('worker.evss.submit_form526_bdd_instructions')

          subject.perform_async(submission.id)
          described_class.drain
        end

        # We don't create these records when uploading to EVSS, since they are only used
        # to poll Lighthouse for the status of the document after Lighthouse receives it
        it 'does not create a Lighthouse526DocumentUpload record' do
          allow_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:submit_upload_document)

          expect do
            subject.perform_async(submission.id)
            described_class.drain
          end.not_to change(Lighthouse526DocumentUpload, :count)
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

      context 'when the disability_compensation_use_api_provider_for_bdd_instructions flipper is enabled' do
        let(:error_class) { 'FooError' }
        let(:error_message) { 'Something broke' }

        let(:retry_block_args) do
          {
            'jid' => form526_job_status.job_id,
            'error_class' => error_class,
            'error_message' => error_message,
            'args' => [form526_submission.id]
          }
        end

        before do
          Flipper.enable(:disability_compensation_use_api_provider_for_bdd_instructions)
        end

        context 'when the ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS feature flag is enabled' do
          before do
            Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS)
          end

          it 'logs the error via the LighthouseSupplementalDocumentUploadProvider' do
            subject.within_sidekiq_retries_exhausted_block(retry_block_args) do
              expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
                .to receive(:log_upload_failure).with(
                  'worker.evss.submit_form526_bdd_instructions',
                  error_class,
                  error_message
                )
            end
          end
        end

        context 'when the ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS feature flag is disabled' do
          before do
            Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS)
          end

          it 'logs the error via the LighthouseSupplementalDocumentUploadProvider' do
            subject.within_sidekiq_retries_exhausted_block(retry_block_args) do
              expect_any_instance_of(EVSSSupplementalDocumentUploadProvider)
                .to receive(:log_upload_failure).with(
                  'worker.evss.submit_form526_bdd_instructions',
                  error_class,
                  error_message
                )
            end
          end
        end
      end
    end
  end
end
