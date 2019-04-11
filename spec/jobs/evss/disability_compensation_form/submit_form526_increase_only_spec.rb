# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  subject { described_class }

  describe '.perform_async' do
    let(:saved_claim) { FactoryBot.create(:va526ez) }
    let(:submitted_claim_id) { 600_130_094 }
    let(:submission) do
      create(:form526_submission,
             user_uuid: user.uuid,
             auth_headers_json: auth_headers.to_json,
             saved_claim_id: saved_claim.id)
    end

    context 'with a successfull submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(submission.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq 'success'
        end
      end
    end

    context 'when retrying a job' do
      it 'doesnt recreate the job status' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(submission.id)

          jid = subject.jobs.last['jid']
          values = {
            form526_submission_id: submission.id,
            job_id: jid,
            job_class: subject.class,
            status: Form526JobStatus::STATUS[:try],
            updated_at: Time.now.utc
          }
          Form526JobStatus.upsert({ job_id: jid }, values)

          described_class.drain
          expect(Form526JobStatus.last.status).to eq 'success'
          expect(Form526JobStatus.count).to eq 1
        end
      end
    end

    context 'with a submission timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'runs the retryable_error_handler and raises a EVSS::DisabilityCompensationForm::GatewayTimeout' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
          expect(Form526JobStatus).to receive(:upsert).twice
          expect(Rails.logger).to receive(:error).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::GatewayTimeout)
        end
      end
    end

    context 'with a client error' do
      it 'sets the job_status to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with a server error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_err_msg') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with a max ep code server error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_max_ep_code') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with a pif in use server error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_pif_in_use') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with an error that is not mapped' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_unmapped') do
          subject.perform_async(submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        subject.perform_async(submission.id)
        described_class.drain
        expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
      end
    end
  end
end
