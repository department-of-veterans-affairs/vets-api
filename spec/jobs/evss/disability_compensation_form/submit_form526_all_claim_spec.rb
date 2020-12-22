# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526AllClaim, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  describe '.perform_async' do
    let(:saved_claim) { FactoryBot.create(:va526ez) }
    let(:submitted_claim_id) { 600_130_094 }
    let(:submission) do
      create(:form526_submission,
             user_uuid: user.uuid,
             auth_headers_json: auth_headers.to_json,
             saved_claim_id: saved_claim.id)
    end

    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(submission.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
          subject.perform_async(submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq 'success'
        end
      end
    end

    context 'when retrying a job' do
      it 'doesnt recreate the job status' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
          subject.perform_async(submission.id)

          jid = subject.jobs.last['jid']
          values = {
            form526_submission_id: submission.id,
            job_id: jid,
            job_class: subject.class,
            status: Form526JobStatus::STATUS[:try],
            updated_at: Time.now.utc
          }
          Form526JobStatus.upsert(values, unique_by: :job_id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to(
            receive(:increment_success).with(false).once
          )
          described_class.drain
          job_status = Form526JobStatus.where(job_id: values[:job_id]).first
          expect(job_status.status).to eq 'success'
          expect(job_status.error_class).to eq nil
          expect(job_status.job_class).to eq 'SubmitForm526AllClaim'
          expect(Form526JobStatus.count).to eq 1
        end
      end
    end

    context 'with a submission timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'runs the retryable_error_handler and raises a EVSS::DisabilityCompensationForm::GatewayTimeout' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
          expect(Rails.logger).to receive(:error).once
          expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
          job_status = Form526JobStatus.find_by(form526_submission_id: submission.id,
                                                job_class: 'SubmitForm526AllClaim')
          expect(job_status.status).to eq 'retryable_error'
          expect(job_status.error_class).to eq 'Common::Exceptions::GatewayTimeout'
          expect(job_status.error_message).to eq 'Gateway timeout'
        end
      end
    end

    context 'with a breakers outage' do
      it 'runs the retryable_error_handler and raises a gateway timeout' do
        EVSS::DisabilityCompensationForm::Configuration.instance.breakers_service.begin_forced_outage!
        subject.perform_async(submission.id)
        expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
        expect(Form526JobStatus).to receive(:upsert).twice
        expect(Rails.logger).to receive(:error).once
        expect { described_class.drain }.to raise_error(Breakers::OutageException)
      end
    end

    context 'with a client error' do
      it 'sets the job_status to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          form_job_status = Form526JobStatus.last
          expect(form_job_status.error_class).to eq 'EVSS::DisabilityCompensationForm::ServiceException'
          expect(form_job_status.job_class).to eq 'SubmitForm526AllClaim'
          expect(form_job_status.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
          expect(form_job_status.error_message).to eq(
            '[{"key"=>"form526.serviceInformation.ConfinementPastActiveDutyDate", "severity"=>"ERROR", "text"=>"The ' \
              'confinement start date is too far in the past"}, {"key"=>"form526.serviceInformation.' \
              'ConfinementWithInServicePeriod", "severity"=>"ERROR", "text"=>"Your period of confinement must be ' \
              'within a single period of service"}, {"key"=>"form526.veteran.homelessness.pointOfContact.' \
              'pointOfContactName.Pattern", "severity"=>"ERROR", "text"=>"must match \\"([a-zA-Z0-9-/]+( ?))*$\\""}]'
          )
        end
      end
    end

    context 'with an upstream service error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_err_msg') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
          expect(Form526JobStatus).to receive(:upsert).twice
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
        end
      end
    end

    context 'with an upstream service error for EP code not valid' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_200_with_ep_not_valid') do
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

    context 'with a unused [418] error' do
      it 'sets the transaction to "retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_200_with_418') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:retryable_error]
        end
      end
    end

    context 'with a BGS error' do
      it 'sets the transaction to "retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_200_with_bgs_error') do
          subject.perform_async(submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:retryable_error]
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
