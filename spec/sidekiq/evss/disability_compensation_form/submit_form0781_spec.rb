# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm0781, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_lighthouse_document_service_provider)
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
end
