# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_fail_submission)
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

    context 'various ICN retrieval scenarios' do
      let!(:form526_submission) { create(:form526_submission) }
      it 'submissions user account has an ICN, as expected' do
        submission.user_account = UserAccount.new(icn: '123498767V222222')
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V222222')
      end

      it 'submissions user account has no ICN, default to Account lookup' do
        submission.user_account = UserAccount.new(icn: nil)
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V234859')
      end

      it 'submission has NO user account, default to Account lookup' do
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V234859')
      end

      it 'submissions user account has no ICN, lookup from past submissions' do
        user_account_with_icn = UserAccount.create!(icn: '123498767V111111')
        create(:form526_submission, user_uuid: submission.user_uuid, user_account: user_account_with_icn)
        submission.user_account = UserAccount.create!(icn: nil)
        submission.save!
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V111111')
      end

      it 'lookup ICN from user verifications, idme_uuid defined' do
        user_account_with_icn = UserAccount.create!(icn: '123498767V333333')
        UserVerification.create!(idme_uuid: submission.user_uuid, user_account_id: user_account_with_icn.id)
        submission.user_account = UserAccount.create!(icn: nil)
        submission.save!
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V333333')
      end

      it 'lookup ICN from user verifications, backing_idme_uuid defined' do
        user_account_with_icn = UserAccount.create!(icn: '123498767V444444')
        UserVerification.create!(dslogon_uuid: Faker::Internet.uuid, backing_idme_uuid: submission.user_uuid, user_account_id: user_account_with_icn.id)
        submission.user_account = UserAccount.create!(icn: nil)
        submission.save!
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V444444')
      end

      it 'lookup ICN from user verifications, alternate provider id defined' do
        user_account_with_icn = UserAccount.create!(icn: '123498767V555555')
        UserVerification.create!(dslogon_uuid: submission.user_uuid, backing_idme_uuid: Faker::Internet.uuid, user_account_id: user_account_with_icn.id)
        submission.user_account = UserAccount.create!(icn: nil)
        submission.save!
        account = subject.new.send(:submission_account, submission)
        expect(account.icn).to eq('123498767V555555')
      end
    end
  end
end
