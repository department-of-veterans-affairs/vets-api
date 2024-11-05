# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm0781, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_use_api_provider_for_0781_uploads)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:evss_claim_id) { 123_456_789 }
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  # contains 0781 and 0781a
  let(:form0781) do
    File.read 'spec/support/disability_compensation_form/submissions/with_0781.json'
  end

  VCR.configure do |c|
    c.default_cassette_options = {
      match_requests_on: [:method,
                          VCR.request_matchers.uri_without_params(:qqfile, :docType, :docTypeDescription)]
    }
    # the response body may not be encoded according to the encoding specified in the HTTP headers
    # VCR will base64 encode the body of the request or response during serialization,
    # in order to preserve the bytes exactly.
    c.preserve_exact_body_bytes do |http_message|
      http_message.body.encoding.name == 'ASCII-8BIT' ||
        !http_message.body.valid_encoding?
    end
  end

  describe '.perform_async' do
    let(:submission) do
      Form526Submission.create(user_uuid: user.uuid,
                               auth_headers_json: auth_headers.to_json,
                               saved_claim_id: saved_claim.id,
                               form_json: form0781,
                               submitted_claim_id: evss_claim_id)
    end

    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(submission.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_0781') do
          subject.perform_async(submission.id)
          jid = subject.jobs.last['jid']
          described_class.drain
          expect(jid).not_to be_empty
        end
      end
    end

    context 'with a submission timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'raises a gateway timeout error' do
        subject.perform_async(submission.id)
        expect { described_class.drain }.to raise_error(StandardError)
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'raises a standard error' do
        subject.perform_async(submission.id)
        expect { described_class.drain }.to raise_error(StandardError)
      end
    end
  end

  context 'catastrophic failure state' do
    describe 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission) }
      let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }

      it 'updates a StatsD counter and updates the status on an exhaustion event' do
        subject.within_sidekiq_retries_exhausted_block({ 'jid' => form526_job_status.job_id }) do
          # Will receieve increment for failure mailer metric
          allow(StatsD).to receive(:increment).with(
            'shared.sidekiq.default.EVSS_DisabilityCompensationForm_Form0781DocumentUploadFailureEmail.enqueue'
          )

          expect(StatsD).to receive(:increment).with("#{subject::STATSD_KEY_PREFIX}.exhausted")
          expect(Rails).to receive(:logger).and_call_original
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end

      context 'when an error occurs during exhaustion handling and FailureEmail fails to enqueue' do
        let!(:failure_email) { EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail }
        let!(:zsf_tag) { Form526Submission::ZSF_DD_TAG_SERVICE }
        let!(:zsf_monitor) { ZeroSilentFailures::Monitor.new(zsf_tag) }

        before do
          Flipper.enable(:form526_send_0781_failure_notification)
          allow(ZeroSilentFailures::Monitor).to receive(:new).with(zsf_tag).and_return(zsf_monitor)
        end

        it 'logs a silent failure' do
          expect(zsf_monitor).to receive(:log_silent_failure).with(
            {
              job_id: form526_job_status.job_id,
              error_class: nil,
              error_message: 'An error occured',
              timestamp: instance_of(Time),
              form526_submission_id: form526_submission.id
            },
            nil,
            call_location: instance_of(ZeroSilentFailures::Monitor::CallLocation)
          )

          args = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }

          expect do
            subject.within_sidekiq_retries_exhausted_block(args) do
              allow(failure_email).to receive(:perform_async).and_raise(StandardError, 'Simulated error')
            end
          end.to raise_error(StandardError, 'Simulated error')
        end
      end

      context 'when the form526_send_0781_failure_notification Flipper is enabled' do
        before do
          Flipper.enable(:form526_send_0781_failure_notification)
        end

        it 'enqueues a failure notification mailer to send to the veteran' do
          subject.within_sidekiq_retries_exhausted_block(
            {
              'jid' => form526_job_status.job_id,
              'args' => [form526_submission.id]
            }
          ) do
            expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail)
              .to receive(:perform_async).with(form526_submission.id)
          end
        end
      end

      context 'when the form526_send_0781_failure_notification Flipper is disabled' do
        before do
          Flipper.disable(:form526_send_0781_failure_notification)
        end

        it 'does not enqueue a failure notification mailer to send to the veteran' do
          subject.within_sidekiq_retries_exhausted_block(
            {
              'jid' => form526_job_status.job_id,
              'args' => [form526_submission.id]
            }
          ) do
            expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail)
              .not_to receive(:perform_async)
          end
        end
      end
    end
  end

  context 'When an ApiProvider is used for uploads' do
    before do
      Flipper.enable(:disability_compensation_use_api_provider_for_0781_uploads)
      # StatsD metrics are incremented in several callbacks we're not testing here so we need to allow them
      allow(StatsD).to receive(:increment)
      # There is an ensure block in the upload_to_vbms method that deletes the generated PDF
      allow(File).to receive(:delete).and_return(nil)
    end

    let(:path_to_0781_fixture) { 'spec/fixtures/pdf_fill/21-0781/simple.pdf' }
    let(:parsed_0781_form) { JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))['form0781'] }
    let(:form0781_only) do
      original = JSON.parse(form0781)
      original['form0781'].delete('form0781a')
      original.to_json
    end

    let(:path_to_0781a_fixture) { 'spec/fixtures/pdf_fill/21-0781a/kitchen_sink.pdf' }
    let(:parsed_0781a_form) { JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))['form0781a'] }
    let(:form0781a_only) do
      original = JSON.parse(form0781)
      original['form0781'].delete('form0781')
      original.to_json
    end

    let(:submission) do
      Form526Submission.create(user_uuid: user.uuid,
                               auth_headers_json: auth_headers.to_json,
                               saved_claim_id: saved_claim.id,
                               form_json: form0781, # contains 0781 and 0781a
                               submitted_claim_id: evss_claim_id)
    end

    let(:perform_upload) do
      subject.perform_async(submission.id)
      described_class.drain
    end

    context 'when the disability_compensation_upload_0781_to_lighthouse flipper is enabled' do
      let(:faraday_response) { instance_double(Faraday::Response) }
      let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }
      let(:lighthouse_0781_document) do
        LighthouseDocument.new(
          claim_id: submission.submitted_claim_id,
          participant_id: submission.auth_headers['va_eauth_pid'],
          document_type: 'L228'
        )
      end
      let(:lighthouse_0781a_document) do
        LighthouseDocument.new(
          claim_id: submission.submitted_claim_id,
          participant_id: submission.auth_headers['va_eauth_pid'],
          document_type: 'L229'
        )
      end
      let(:expected_statsd_metrics_prefix) do
        'worker.evss.submit_form0781.lighthouse_supplemental_document_upload_provider'
      end
      let(:error_response_body) do
        # From vcr_cassettes/lighthouse/benefits_claims/documents/lighthouse_form_526_document_upload_400.yml
        {
          'errors' => [
            {
              'detail' => 'Something broke',
              'status' => 400,
              'title' => 'Bad Request',
              'instance' => Faker::Internet.uuid
            }
          ]
        }
      end

      before do
        Flipper.enable(:disability_compensation_upload_0781_to_lighthouse)

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

      context 'when a submission has both 0781 and 0781a' do
        context 'when the request is successful' do
          it 'uploads both documents to Lighthouse' do
            # 0781
            allow_any_instance_of(described_class)
              .to receive(:generate_stamp_pdf)
              .with(parsed_0781_form, submission.submitted_claim_id, '21-0781')
              .and_return(path_to_0781_fixture)

            allow_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
              .to receive(:generate_upload_document)
              .and_return(lighthouse_0781_document)

            expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService)
              .to receive(:call)
              .with(File.read(path_to_0781_fixture), lighthouse_0781a_document)

            # 0781a
            allow_any_instance_of(described_class)
              .to receive(:generate_stamp_pdf)
              .with(parsed_0781a_form, submission.submitted_claim_id, '21-0781a')
              .and_return(path_to_0781a_fixture)

            allow_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
              .to receive(:generate_upload_document)
              .and_return(lighthouse_0781a_document)

            expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService)
              .to receive(:call)
              .with(File.read(path_to_0781a_fixture), lighthouse_0781a_document)

            perform_upload
          end

          it 'logs the upload attempt with the correct job prefix' do
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_attempt"
            ).twice # For 0781 and 0781a
            perform_upload
          end

          it 'increments the correct StatsD success metric' do
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_success"
            ).twice # For 0781 and 0781a

            perform_upload
          end

          it 'creates a pending Lighthouse526DocumentUpload record so we can poll Lighthouse later' do
            upload_attributes = {
              aasm_state: 'pending',
              form526_submission_id: submission.id,
              lighthouse_document_request_id: lighthouse_request_id
            }

            expect(Lighthouse526DocumentUpload.where(**upload_attributes).count).to eq(0)

            perform_upload
            expect(Lighthouse526DocumentUpload.where(**upload_attributes)
            .where(document_type: 'Form 0781').count).to eq(1)
            expect(Lighthouse526DocumentUpload.where(**upload_attributes)
            .where(document_type: 'Form 0781a').count).to eq(1)
          end
        end

        context 'when Lighthouse returns an error response' do
          before do
            allow(faraday_response).to receive(:body).and_return(error_response_body)
          end

          it 'logs the Lighthouse error response' do
            # 0781
            expect(Rails.logger).to receive(:error).with(
              'LighthouseSupplementalDocumentUploadProvider upload failed',
              {
                class: 'LighthouseSupplementalDocumentUploadProvider',
                submission_id: submission.id,
                submitted_claim_id: submission.submitted_claim_id,
                user_uuid: submission.user_uuid,
                va_document_type_code: 'L228',
                primary_form: 'Form526',
                lighthouse_error_response: error_response_body
              }
            )
            # 0781a
            expect(Rails.logger).to receive(:error).with(
              'LighthouseSupplementalDocumentUploadProvider upload failed',
              {
                class: 'LighthouseSupplementalDocumentUploadProvider',
                submission_id: submission.id,
                submitted_claim_id: submission.submitted_claim_id,
                user_uuid: submission.user_uuid,
                va_document_type_code: 'L229',
                primary_form: 'Form526',
                lighthouse_error_response: error_response_body
              }
            )

            perform_upload
          end

          it 'increments the correct status failure metric' do
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_failure"
            ).twice # For 0781 and 0781a

            perform_upload
          end
        end
      end

      context 'when a submission has 0781 only' do
        before do
          submission.update(form_json: form0781_only)
        end

        context 'when the request is successful' do
          it 'uploads to Lighthouse' do
            allow_any_instance_of(described_class)
              .to receive(:generate_stamp_pdf)
              .with(parsed_0781_form, submission.submitted_claim_id, '21-0781')
              .and_return(path_to_0781_fixture)

            allow_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
              .to receive(:generate_upload_document)
              .and_return(lighthouse_0781_document)

            expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService)
              .to receive(:call)
              .with(File.read(path_to_0781_fixture), lighthouse_0781_document)

            perform_upload
          end
        end

        context 'when Lighthouse returns an error response' do
          before do
            allow(faraday_response).to receive(:body).and_return(error_response_body)
          end

          it 'logs the Lighthouse error response' do
            expect(Rails.logger).to receive(:error).with(
              'LighthouseSupplementalDocumentUploadProvider upload failed',
              {
                class: 'LighthouseSupplementalDocumentUploadProvider',
                submission_id: submission.id,
                submitted_claim_id: submission.submitted_claim_id,
                user_uuid: submission.user_uuid,
                va_document_type_code: 'L228',
                primary_form: 'Form526',
                lighthouse_error_response: error_response_body
              }
            )

            perform_upload
          end

          it 'increments the correct status failure metric' do
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_failure"
            )

            perform_upload
          end
        end
      end

      context 'when a submission has 0781a only' do
        before do
          submission.update(form_json: form0781a_only)
        end

        context 'when a request is successful' do
          it 'uploads to Lighthouse' do
            allow_any_instance_of(described_class)
              .to receive(:generate_stamp_pdf)
              .with(parsed_0781a_form, submission.submitted_claim_id, '21-0781a')
              .and_return(path_to_0781a_fixture)

            allow_any_instance_of(LighthouseSupplementalDocumentUploadProvider)
              .to receive(:generate_upload_document)
              .and_return(lighthouse_0781a_document)

            expect(BenefitsDocuments::Form526::UploadSupplementalDocumentService)
              .to receive(:call)
              .with(File.read(path_to_0781a_fixture), lighthouse_0781a_document)

            perform_upload
          end
        end

        context 'when Lighthouse returns an error response' do
          before do
            allow(faraday_response).to receive(:body).and_return(error_response_body)
          end

          it 'logs the Lighthouse error response' do
            expect(Rails.logger).to receive(:error).with(
              'LighthouseSupplementalDocumentUploadProvider upload failed',
              {
                class: 'LighthouseSupplementalDocumentUploadProvider',
                submission_id: submission.id,
                submitted_claim_id: submission.submitted_claim_id,
                user_uuid: submission.user_uuid,
                va_document_type_code: 'L229',
                primary_form: 'Form526',
                lighthouse_error_response: error_response_body
              }
            )

            perform_upload
          end

          it 'increments the correct status failure metric' do
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_failure"
            )

            perform_upload
          end
        end
      end
    end

    context 'when the disability_compensation_upload_0781_to_lighthouse flipper is disabled' do
      let(:evss_claim_0781_document) do
        EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          document_type: 'L228'
        )
      end
      let(:evss_claim_0781a_document) do
        EVSSClaimDocument.new(
          evss_claim_id: submission.submitted_claim_id,
          document_type: 'L229'
        )
      end
      let(:client_stub) { instance_double(EVSS::DocumentsService) }
      let(:expected_statsd_metrics_prefix) { 'worker.evss.submit_form0781.evss_supplemental_document_upload_provider' }

      before do
        Flipper.disable(:disability_compensation_upload_0781_to_lighthouse)
        allow(EVSS::DocumentsService).to receive(:new) { client_stub }
        allow(client_stub).to receive(:upload)
        # 0781
        allow_any_instance_of(described_class)
          .to receive(:generate_stamp_pdf)
          .with(parsed_0781_form, submission.submitted_claim_id, '21-0781')
          .and_return(path_to_0781_fixture)
        allow_any_instance_of(EVSSSupplementalDocumentUploadProvider)
          .to receive(:generate_upload_document)
          .with('simple.pdf')
          .and_return(evss_claim_0781_document)

        # 0781a
        allow_any_instance_of(described_class)
          .to receive(:generate_stamp_pdf)
          .with(parsed_0781a_form, submission.submitted_claim_id, '21-0781a')
          .and_return(path_to_0781a_fixture)
        allow_any_instance_of(EVSSSupplementalDocumentUploadProvider)
          .to receive(:generate_upload_document)
          .with('kitchen_sink.pdf')
          .and_return(evss_claim_0781a_document)
      end

      context 'when a submission has both 0781 and 0781a' do
        context 'when the request is successful' do
          it 'uploads both documents to EVSS' do
            expect(client_stub).to receive(:upload).with(File.read(path_to_0781_fixture), evss_claim_0781_document)

            expect(client_stub).to receive(:upload).with(File.read(path_to_0781a_fixture), evss_claim_0781a_document)

            perform_upload
          end

          it 'logs the upload attempt with the correct job prefix' do
            allow(client_stub).to receive(:upload)
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_attempt"
            ).twice # For 0781 and 0781a

            perform_upload
          end

          it 'increments the correct StatsD success metric' do
            allow(client_stub).to receive(:upload)
            expect(StatsD).to receive(:increment).with(
              "#{expected_statsd_metrics_prefix}.upload_success"
            ).twice # For 0781 and 0781a

            perform_upload
          end
        end

        context 'when an upload raises an EVSS response error' do
          it 'logs an upload error and re-raises the error' do
            allow(client_stub).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSError)
            expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_upload_failure)

            expect do
              subject.perform_async(submission.id)
              described_class.drain
            end.to raise_error(EVSS::ErrorMiddleware::EVSSError)
          end
        end
      end

      context 'when a submission has only a 0781 form' do
        before do
          submission.update(form_json: form0781_only)
        end

        context 'when the request is successful' do
          it 'uploads to EVSS' do
            submission.update(form_json: form0781_only)
            expect(client_stub).to receive(:upload).with(File.read(path_to_0781_fixture), evss_claim_0781_document)

            perform_upload
          end
        end

        context 'when an upload raises an EVSS response error' do
          it 'logs an upload error and re-raises the error' do
            allow(client_stub).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSError)
            expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_upload_failure)

            expect do
              subject.perform_async(submission.id)
              described_class.drain
            end.to raise_error(EVSS::ErrorMiddleware::EVSSError)
          end
        end
      end

      context 'when a submission has only a 0781a form' do
        context 'when the request is successful' do
          it 'uploads the 0781a document to EVSS' do
            submission.update(form_json: form0781a_only)
            expect(client_stub).to receive(:upload).with(File.read(path_to_0781a_fixture), evss_claim_0781a_document)

            perform_upload
          end
        end

        context 'when an upload raises an EVSS response error' do
          it 'logs an upload error and re-raises the error' do
            allow(client_stub).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSError)
            expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:log_upload_failure)

            expect do
              subject.perform_async(submission.id)
              described_class.drain
            end.to raise_error(EVSS::ErrorMiddleware::EVSSError)
          end
        end
      end
    end
  end
end
