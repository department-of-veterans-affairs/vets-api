# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all

    Flipper.disable(:disability_compensation_use_api_provider_for_submit_veteran_upload)
    Flipper.disable(:form526_send_document_upload_failure_notification)
  end

  let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
  let(:user_account) { user.user_account }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads,
           user_uuid: user.uuid,
           user_account:,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           submitted_claim_id: '600130094')
  end
  let(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission: submission, job_id: 1) }
  let(:upload_data) { [submission.form[Form526Submission::FORM_526_UPLOADS].first] }

  let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
  let!(:attachment) do
    sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
    sea.set_file_data!(file)
    sea.save!
    sea
  end

  describe 'perform' do
    let(:document_data) { double(:document_data, valid?: true) }

    context 'when file_data exists' do
      it 'calls the documents service api with file body and document data' do
        VCR.use_cassette('evss/documents/upload_with_errors') do
          expect(EVSSClaimDocument)
            .to receive(:new)
            .with(
              evss_claim_id: submission.submitted_claim_id,
              file_name: upload_data.first['name'],
              tracked_item_id: nil,
              document_type: upload_data.first['attachmentId']
            )
            .and_return(document_data)

          subject.perform_async(submission.id, upload_data)
          expect_any_instance_of(EVSS::DocumentsService).to receive(:upload).with(file.read, document_data)
          described_class.drain
        end
      end

      context 'with a timeout' do
        it 'logs a retryable error and re-raises the original error' do
          allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
            .and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
          subject.perform_async(submission.id, upload_data)
          expect(Form526JobStatus).to receive(:upsert).twice
          expect { described_class.drain }.to raise_error(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        end
      end

      context 'when all retries are exhausted' do
        let!(:form526_job_status) do
          create(
            :form526_job_status,
            :retryable_error,
            form526_submission: submission,
            job_id: 1
          )
        end

        context 'when the form526_send_document_upload_failure_notification Flipper is enabled' do
          before do
            Flipper.enable(:form526_send_document_upload_failure_notification)
          end

          it 'enqueues a failure notification mailer to send to the veteran' do
            subject.within_sidekiq_retries_exhausted_block(
              {
                'jid' => form526_job_status.job_id,
                'args' => [submission.id, upload_data]
              }
            ) do
              expect(EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail)
                .to receive(:perform_async).with(submission.id, attachment.guid)
            end
          end
        end

        context 'when the form526_send_document_upload_failure_notification Flipper is disabled' do
          it 'does not enqueue a failure notification mailer to send to the veteran' do
            subject.within_sidekiq_retries_exhausted_block(
              {
                'jid' => form526_job_status.job_id,
                'args' => [submission.id, upload_data]
              }
            ) do
              expect(EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail)
                .not_to receive(:perform_async)
            end
          end
        end
      end
    end

    context 'when misnamed file_data exists' do
      let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1_actually_jpg.png', 'image/png') }
      let!(:attachment) do
        sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
        sea.set_file_data!(file)
        sea.save
      end

      it 'calls the documents service api with file body and document data' do
        VCR.use_cassette('evss/documents/upload_with_errors') do
          expect(EVSSClaimDocument)
            .to receive(:new)
            .with(
              evss_claim_id: submission.submitted_claim_id,
              file_name: 'converted_sm_file1_actually_jpg_png.jpg',
              tracked_item_id: nil,
              document_type: upload_data.first['attachmentId']
            )
            .and_return(document_data)

          subject.perform_async(submission.id, upload_data)
          expect_any_instance_of(EVSS::DocumentsService).to receive(:upload).with(file.read, document_data)
          described_class.drain
        end
      end
    end

    context 'when get_file is nil' do
      let(:attachment) { double(:attachment, get_file: nil) }

      it 'logs a non_retryable_error' do
        subject.perform_async(submission.id, upload_data)
        expect(Form526JobStatus).to receive(:upsert).twice
        expect { described_class.drain }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'When an ApiProvider is used for uploads' do
    before do
      Flipper.enable(:disability_compensation_use_api_provider_for_submit_veteran_upload)
      # StatsD metrics are incremented in several callbacks we're not testing here so we need to allow them
      allow(StatsD).to receive(:increment)
    end

    context 'when file_data exists' do
      let(:perform_upload) do
        subject.perform_async(submission.id, upload_data.first)
        described_class.drain
      end

      context 'when the disability_compensation_upload_veteran_evidence_to_lighthouse flipper is enabled' do
        let(:faraday_response) { instance_double(Faraday::Response) }
        let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }
        let(:expected_statsd_metrics_prefix) do
          'worker.evss.submit_form526_upload.lighthouse_supplemental_document_upload_provider'
        end

        let(:expected_lighthouse_document) do
          LighthouseDocument.new(
            claim_id: submission.submitted_claim_id,
            participant_id: user.participant_id,
            document_type: upload_data.first['attachmentId'],
            file_name: upload_data.first['name'],
            supporting_evidence_attachment: attachment
          )
        end

        before do
          Flipper.enable(:disability_compensation_upload_veteran_evidence_to_lighthouse)

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

        it 'uploads the veteran evidence to Lighthouse' do
          expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
            .with(file.read, expected_lighthouse_document)

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
            document_type: 'Veteran Upload',
            lighthouse_document_request_id: lighthouse_request_id
          }

          expect(Lighthouse526DocumentUpload.where(**upload_attributes).count).to eq(0)

          perform_upload

          expect(Lighthouse526DocumentUpload.where(**upload_attributes).count).to eq(1)
        end

        # This is a possibility accounted for in the existing EVSS submission code.
        # The original attachment object does not have a converted_filename.
        context 'when the SupportingEvidenceAttachment returns a converted_filename' do
          before do
            attachment.update!(file_data: JSON.parse(attachment.file_data)
                      .merge('converted_filename' => 'converted_filename.pdf').to_json)
          end

          let(:expected_lighthouse_document_with_converted_file_name) do
            LighthouseDocument.new(
              claim_id: submission.submitted_claim_id,
              participant_id: user.participant_id,
              document_type: upload_data.first['attachmentId'],
              file_name: 'converted_filename.pdf',
              supporting_evidence_attachment: attachment
            )
          end

          it 'uses the converted_filename instead of the metadata in upload_data["name"]' do
            expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
              .with(file.read, expected_lighthouse_document_with_converted_file_name)

            perform_upload
          end
        end

        context 'when Lighthouse returns an error response' do
          let(:exception_errors) { [{ detail: 'Something Broke' }] }

          before do
            # Skip additional logging that occurs in Lighthouse::ServiceException handling
            allow(Rails.logger).to receive(:error)

            allow(BenefitsDocuments::Form526::UploadSupplementalDocumentService).to receive(:call)
              .and_raise(Common::Exceptions::BadRequest.new(errors: exception_errors))
          end

          it 'logs the Lighthouse error response' do
            expect(Rails.logger).to receive(:error).with(
              'LighthouseSupplementalDocumentUploadProvider upload failed',
              {
                class: 'LighthouseSupplementalDocumentUploadProvider',
                submitted_claim_id: submission.submitted_claim_id,
                submission_id: submission.id,
                user_uuid: submission.user_uuid,
                va_document_type_code: 'L451',
                primary_form: 'Form526',
                error_info: exception_errors
              }
            )

            expect { perform_upload }.to raise_error(Common::Exceptions::BadRequest)
          end

          it 'increments the correct status failure metric' do
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_failure"
            )

            expect { perform_upload }.to raise_error(Common::Exceptions::BadRequest)
          end
        end
      end

      # Upload to EVSS
      context 'when the disability_compensation_upload_veteran_evidence_to_lighthouse flipper is disabled' do
        before do
          Flipper.disable(:disability_compensation_upload_veteran_evidence_to_lighthouse)
          allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
        end

        let(:evss_claim_document) do
          EVSSClaimDocument.new(
            evss_claim_id: submission.submitted_claim_id,
            document_type: upload_data.first['attachmentId'],
            file_name: upload_data.first['name']
          )
        end

        let(:expected_statsd_metrics_prefix) do
          'worker.evss.submit_form526_upload.evss_supplemental_document_upload_provider'
        end

        it 'uploads the document via the EVSS Documents Service' do
          expect_any_instance_of(EVSS::DocumentsService).to receive(:upload)
            .with(file.read, evss_claim_document)

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
          it 'logs an upload error and re-raises the error' do
            allow_any_instance_of(EVSS::DocumentsService)
              .to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSError)

            expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_upload_failure)

            expect { perform_upload }.to raise_error(EVSS::ErrorMiddleware::EVSSError)
          end
        end
      end
    end
  end

  context 'catastrophic failure state' do
    describe 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission, :with_uploads, user_account:) }
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
          Flipper.enable(:disability_compensation_use_api_provider_for_submit_veteran_upload)
        end

        let(:sidekiq_job_exhaustion_errors) do
          {
            'jid' => form526_job_status.job_id,
            'error_class' => 'Broken Job Error',
            'error_message' => 'Your Job Broke',
            'args' => [form526_submission.id, upload_data.first]
          }
        end

        context 'for a Lighthouse upload' do
          it 'logs the job failure' do
            Flipper.enable(:disability_compensation_upload_veteran_evidence_to_lighthouse)

            subject.within_sidekiq_retries_exhausted_block(sidekiq_job_exhaustion_errors) do
              expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
                .to receive(:log_uploading_job_failure)
                .with(EVSS::DisabilityCompensationForm::SubmitUploads, 'Broken Job Error', 'Your Job Broke')
            end
          end
        end

        context 'for an EVSS Upload' do
          it 'logs the job failure' do
            Flipper.disable(:disability_compensation_upload_veteran_evidence_to_lighthouse)

            subject.within_sidekiq_retries_exhausted_block(sidekiq_job_exhaustion_errors) do
              expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_uploading_job_failure)
                .with(EVSS::DisabilityCompensationForm::SubmitUploads, 'Broken Job Error', 'Your Job Broke')
            end
          end
        end
      end
    end

    describe 'when an error occurs during exhaustion handling and FailureEmail fails to enqueue' do
      let!(:zsf_tag) { Form526Submission::ZSF_DD_TAG_SERVICE }
      let!(:zsf_monitor) { ZeroSilentFailures::Monitor.new(zsf_tag) }
      let!(:failure_email) { EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail }

      before do
        Flipper.enable(:form526_send_document_upload_failure_notification)
        allow(ZeroSilentFailures::Monitor).to receive(:new).with(zsf_tag).and_return(zsf_monitor)
      end

      it 'logs a silent failure' do
        expect(zsf_monitor).to receive(:log_silent_failure).with(
          {
            job_id: form526_job_status.job_id,
            error_class: nil,
            error_message: 'An error occurred',
            timestamp: instance_of(Time),
            form526_submission_id: submission.id
          },
          user_account.id,
          call_location: instance_of(Logging::CallLocation)
        )

        args = { 'jid' => form526_job_status.job_id, 'args' => [submission.id, upload_data] }

        expect do
          subject.within_sidekiq_retries_exhausted_block(args) do
            allow(failure_email).to receive(:perform_async).and_raise(StandardError, 'Simulated error')
          end
        end.to raise_error(StandardError, 'Simulated error')
      end
    end
  end
end
