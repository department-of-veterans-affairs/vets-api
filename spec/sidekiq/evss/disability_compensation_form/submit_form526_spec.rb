# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_fail_submission)
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
    end
  end
end
