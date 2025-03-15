# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526Cleanup, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  let(:user) { create(:user, :loa3) }
  let(:submission) { create(:form526_submission, user_uuid: user.uuid) }

  describe '.perform_async' do
    context 'with a successful call' do
      it 'deletes the in progress form' do
        create(:in_progress_form, user_uuid: user.uuid, form_id: '21-526EZ')
        subject.perform_async(submission.id)
        expect { described_class.drain }.to change(InProgressForm, :count).by(-1)
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
