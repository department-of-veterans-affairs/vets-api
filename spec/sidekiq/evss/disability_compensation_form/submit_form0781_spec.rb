# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm0781, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_use_api_provider_for_0781)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:evss_claim_id) { 123_456_789 }
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:form0781) { File.read 'spec/support/disability_compensation_form/submissions/with_0781.json' }

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

    context 'when the disability_compensation_use_api_provider_for_0781 flipper is enabled' do
      before do
        Flipper.enable(:disability_compensation_use_api_provider_for_0781)
      end

      context 'when the ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781 feature flag is enabled' do
        let(:faraday_response) { instance_double(Faraday::Response) }
        let(:lighthouse_request_id) { Faker::Number.number(digits: 8) }
        let(:generated_pdf_file_name) {/.+\.pdf\z/}

        before do
          Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781)

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
          lighthouse_document_0781 = instance_double(LighthouseDocument, document_type: 'L228')

          lighthouse_document_0781a = instance_double(LighthouseDocument, document_type: 'L229')

          # The test submission includes 0781(doc_type L228) and 0781A(doc_type L229), which calls generate_upload_document once for each doc_type
          expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:generate_upload_document)
            .with(
              generated_pdf_file_name,
              'L228')
            .and_return(lighthouse_document_0781)
          
            expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:generate_upload_document)
            .with(
              generated_pdf_file_name,
              'L229')
            .and_return(lighthouse_document_0781a)

          expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:submit_upload_document)
          .with(
            lighthouse_document_0781,
            anything #arg for generated pdf file_body
          )

          expect_any_instance_of(LighthouseSupplementalDocumentUploadProvider).to receive(:submit_upload_document)
          .with(
            lighthouse_document_0781a,
            anything #arg for generated pdf file_body
          )

          subject.perform_async(submission.id)
          described_class.drain
        end
      end

      context 'when the ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781 feature flag is disabled' do
        before do 
          Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781)
        end

        it 'uploads the document via the EVSSSupplementalDocumentUploadProvider' do
          evss_document_0781 = instance_double(EVSSClaimDocument, document_type: 'L228')

          evss_document_0781a = instance_double(EVSSClaimDocument, document_type: 'L229')

          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:generate_upload_document)
          .with(
            anything, #arg from generated_stamp_pdf
            'L228')
          .and_return(evss_document_0781)

          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:generate_upload_document)
          .with(
            anything, #arg from generated_stamp_pdf
            'L229')
          .and_return(evss_document_0781a)

          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:submit_upload_document)
          .with(
            evss_document_0781,
            anything #arg for generated file_body
          )

          expect_any_instance_of(EVSSSupplementalDocumentUploadProvider).to receive(:submit_upload_document)
          .with(
            evss_document_0781a,
            anything #arg for generated file_body
          )
          
          subject.perform_async(submission.id)
          described_class.drain
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
    end
  end
end
