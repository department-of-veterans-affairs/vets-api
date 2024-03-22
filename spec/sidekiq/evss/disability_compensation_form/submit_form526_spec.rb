# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
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

    context 'when the base class is used' do
      it 'raises an error as a subclass should be used to perform the job' do
        allow_any_instance_of(Form526Submission).to receive(:prepare_for_evss!).and_return(nil)
        expect { subject.new.perform(submission.id) }.to raise_error NotImplementedError
      end
    end

    context 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission) }
      let!(:form526_job_status) do
        create(:form526_job_status, :non_retryable_error, form526_submission:, job_id: 1)
      end

      it 'transitions the submission to a failure state' do
        job_params = { 'jid' => form526_job_status.job_id, 'args' => [submission.id] }
        allow(Sidekiq::Form526JobStatusTracker::JobTracker).to receive(:send_backup_submission_if_enabled)

        subject.within_sidekiq_retries_exhausted_block(job_params) do
          # block is required to use this functionality.  All we care about is
          # the state of the submission after this exhaustion hook has run
          true
        end
        submission.reload
        expect(submission.aasm_state).to eq 'failed_primary_delivery'
      end
    end
  end
end
