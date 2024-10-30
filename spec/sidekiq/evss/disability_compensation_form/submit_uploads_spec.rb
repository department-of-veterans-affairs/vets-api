# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_lighthouse_document_service_provider)
    Flipper.disable(:form526_send_document_upload_failure_notification)
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
  let(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission: submission, job_id: 1) }
  let(:upload_data) { [submission.form[Form526Submission::FORM_526_UPLOADS].first] }

  describe 'perform' do
    let(:document_data) { double(:document_data, valid?: true) }

    context 'when file_data exists' do
      let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
      let!(:attachment) do
        sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
        sea.set_file_data!(file)
        sea.save!
      end

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
        let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
        let!(:attachment) do
          sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
          sea.set_file_data!(file)
          sea.save!
          sea
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

  context 'catastrophic failure state' do
    describe 'when all retries are exhausted' do
      it 'updates a StatsD counter and updates the status on an exhaustion event' do
        subject.within_sidekiq_retries_exhausted_block({ 'jid' => form526_job_status.job_id }) do
          expect(StatsD).to receive(:increment).with("#{subject::STATSD_KEY_PREFIX}.exhausted")
          expect(Rails).to receive(:logger).and_call_original
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
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
            error_message: 'An error occured',
            timestamp: instance_of(Time),
            form526_submission_id: submission.id
          },
          nil,
          call_location: instance_of(ZeroSilentFailures::Monitor::CallLocation)
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
