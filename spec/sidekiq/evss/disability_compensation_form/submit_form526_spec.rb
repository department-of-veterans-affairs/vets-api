# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_fail_submission) # rubocop:disable Project/ForbidFlipperToggleInSpecs
  end

  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  describe '.perform_async' do
    let(:saved_claim) { create(:va526ez) }
    let(:submitted_claim_id) { 600_130_094 }
    let(:submission) do
      create(:form526_submission,
             user_uuid: user.uuid,
             auth_headers_json: auth_headers.to_json,
             saved_claim_id: saved_claim.id)
    end

    context 'when the base class is used' do
      it 'raises an error as a subclass should be used to perform the job' do
        allow_any_instance_of(Form526Submission).to receive(:prepare_for_evss!).and_return(nil)
        expect { subject.new.perform(submission.id) }.to raise_error NotImplementedError
      end
    end

    context 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission) }
      let!(:form526_job_status) { create(:form526_job_status, :non_retryable_error, form526_submission:, job_id: 1) }

      it 'marks the job status as exhausted' do
        job_params = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }
        allow(Sidekiq::Form526JobStatusTracker::JobTracker).to receive(:send_backup_submission_if_enabled)

        subject.within_sidekiq_retries_exhausted_block(job_params) do
          # block is required to use this functionality
          true
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end

      context 'when logging errors in sidekiq_retries_exhausted callback' do
        let!(:form526_submission) { create(:form526_submission) }
        let!(:form526_job_status) do
          create(:form526_job_status, :non_retryable_error, form526_submission:, job_id: '123abc')
        end
        let(:job_params) do
          {
            'class' => 'EVSS::DisabilityCompensationForm::SubmitForm526',
            'jid' => '123abc',
            'args' => [form526_submission.id],
            'error_message' => 'Original failure reason',
            'error_class' => 'StandardError'
          }
        end

        before do
          allow(Sidekiq::Form526JobStatusTracker::JobTracker).to receive(:send_backup_submission_if_enabled)
        end

        it 'logs error details to Rails.logger when job_exhausted fails' do
          # Simulate job_exhausted failing by making find_by return nil
          allow(Form526JobStatus).to receive(:find_by).with(job_id: '123abc').and_return(nil)

          # The JobTracker logs its own error message first
          expect(Rails.logger).to receive(:error).with(
            'Failure in SubmitForm526#sidekiq_retries_exhausted',
            hash_including(
              job_id: '123abc',
              submission_id: form526_submission.id,
              messaged_content: kind_of(String)
            )
          )

          # Then our log_error method is called and logs again
          expect(Rails.logger).to receive(:error).with(
            'SubmitForm526#sidekiq_retries_exhausted error',
            hash_including(
              job_class: 'SubmitForm526',
              job_id: '123abc',
              submission_id: form526_submission.id,
              error_message: kind_of(String),
              original_job_failure_reason: 'Original failure reason'
            )
          )

          # This will trigger the error logging in the sidekiq_retries_exhausted callback
          subject.within_sidekiq_retries_exhausted_block(job_params) do
            true
          end
        end

        it 'can be called as a class method directly' do
          test_error = StandardError.new('Test error message')

          expect(Rails.logger).to receive(:error).with(
            'SubmitForm526#sidekiq_retries_exhausted error',
            {
              job_class: 'SubmitForm526',
              job_id: '123abc',
              submission_id: form526_submission.id,
              error_message: 'Test error message',
              original_job_failure_reason: 'Original failure reason'
            }
          )

          # Call the class method directly
          described_class.log_error(job_params, test_error)
        end

        it 'logs error when Form526Submission.find fails' do
          # Allow job_exhausted to succeed
          allow(Form526JobStatus).to receive(:find_by).with(job_id: '123abc').and_return(form526_job_status)
          allow(form526_job_status).to receive(:update)

          # But make Form526Submission.find fail
          allow(Form526Submission).to receive(:find).and_raise(ActiveRecord::RecordNotFound)

          expect(Rails.logger).to receive(:warn).with(
            'Submit Form 526 Retries exhausted',
            hash_including(job_id: '123abc')
          )

          expect(Rails.logger).to receive(:error).with(
            'SubmitForm526#sidekiq_retries_exhausted error',
            hash_including(
              job_class: 'SubmitForm526',
              job_id: '123abc',
              submission_id: form526_submission.id,
              error_message: kind_of(String),
              original_job_failure_reason: 'Original failure reason'
            )
          )

          subject.within_sidekiq_retries_exhausted_block(job_params) do
            true
          end
        end

        it 'logs error when email notification fails' do
          # Setup successful job_exhausted
          allow(Form526JobStatus).to receive(:find_by).with(job_id: '123abc').and_return(form526_job_status)
          allow(form526_job_status).to receive(:update)

          # Setup submission that will trigger email notification
          job_params['error_message'] = 'PIF in use'
          allow(Form526Submission).to receive(:find).and_return(form526_submission)
          allow(form526_submission).to receive(:submit_with_birls_id_that_hasnt_been_tried_yet!).and_return(nil)
          allow(Flipper).to receive(:enabled?).with(:disability_compensation_pif_fail_notification).and_return(true)
          allow(form526_submission).to receive(:get_first_name).and_raise(StandardError.new('Email error'))

          expect(Rails.logger).to receive(:warn).with(
            'Submit Form 526 Retries exhausted',
            hash_including(job_id: '123abc')
          )

          expect(Rails.logger).to receive(:error).with(
            'SubmitForm526#sidekiq_retries_exhausted error',
            hash_including(
              job_class: 'SubmitForm526',
              job_id: '123abc',
              submission_id: form526_submission.id,
              error_message: 'Email error',
              original_job_failure_reason: 'PIF in use'
            )
          )

          subject.within_sidekiq_retries_exhausted_block(job_params) do
            true
          end
        end
      end
    end
  end
end
