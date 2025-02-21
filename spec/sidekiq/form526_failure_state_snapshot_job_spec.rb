# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526FailureStateSnapshotJob, type: :worker do
  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  let!(:olden_times) { (Form526Submission::MAX_PENDING_TIME + 1.day).ago }
  let!(:modern_times) { 2.days.ago }
  let!(:end_date) { Time.zone.today.beginning_of_day }
  let!(:start_date) { end_date - 1.week }

  describe '526 state logging' do
    let!(:new_unprocessed) do
      Timecop.freeze(modern_times) do
        create(:form526_submission)
      end
    end
    let!(:old_unprocessed) do
      Timecop.freeze(olden_times) do
        create(:form526_submission)
      end
    end
    let!(:new_primary_success) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_submitted_claim_id, :with_one_succesful_job)
      end
    end
    let!(:old_primary_success) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_submitted_claim_id, :with_one_succesful_job)
      end
    end
    let!(:new_backup_pending) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :backup_path, :with_failed_primary_job)
      end
    end
    let!(:old_backup_pending) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :backup_path, :with_failed_primary_job)
      end
    end
    let!(:new_backup_success) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :backup_path, :paranoid_success, :with_failed_primary_job)
      end
    end
    let!(:old_backup_success) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :backup_path, :paranoid_success, :with_failed_primary_job)
      end
    end
    let!(:new_backup_vbms) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :backup_path, :backup_accepted, :with_failed_primary_job)
      end
    end
    let!(:old_backup_vbms) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :backup_path, :backup_accepted, :with_failed_primary_job)
      end
    end
    let!(:new_backup_rejected) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :backup_path, :backup_rejected, :with_failed_primary_job)
      end
    end
    let!(:old_backup_rejected) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :backup_path, :backup_rejected, :with_failed_primary_job)
      end
    end
    let!(:new_double_job_failure) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_failed_primary_job, :with_failed_backup_job)
      end
    end
    let!(:old_double_job_failure) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_failed_primary_job, :with_failed_backup_job)
      end
    end
    let!(:new_double_job_failure_remediated) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_failed_primary_job, :with_failed_backup_job, :remediated)
      end
    end
    let!(:old_double_job_failure_remediated) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_failed_primary_job, :with_failed_backup_job, :remediated)
      end
    end
    let!(:new_double_job_failure_de_remediated) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_failed_primary_job, :with_failed_backup_job, :no_longer_remediated)
      end
    end
    let!(:old_double_job_failure_de_remediated) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_failed_primary_job, :with_failed_backup_job, :no_longer_remediated)
      end
    end
    let!(:new_no_job_remediated) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :remediated)
      end
    end
    let!(:old_no_job_remediated) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :remediated)
      end
    end
    let!(:new_backup_paranoid) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :backup_path, :with_failed_primary_job, :paranoid_success)
      end
    end
    let!(:old_backup_paranoid) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :backup_path, :with_failed_primary_job, :paranoid_success)
      end
    end
    let!(:still_running_with_retryable_errors) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_one_failed_job)
      end
    end
    # RARE EDGECASES
    let!(:new_no_job_de_remediated) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :no_longer_remediated)
      end
    end
    let!(:old_no_job_de_remediated) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :no_longer_remediated)
      end
    end
    let!(:new_double_success) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_submitted_claim_id, :backup_path)
      end
    end
    let!(:old_double_success) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_submitted_claim_id, :backup_path)
      end
    end
    let!(:new_triple_success) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_submitted_claim_id, :backup_path, :remediated)
      end
    end
    let!(:old_triple_success) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_submitted_claim_id, :backup_path, :remediated)
      end
    end
    let!(:new_double_success_de_remediated) do
      Timecop.freeze(modern_times) do
        create(:form526_submission, :with_submitted_claim_id, :backup_path, :no_longer_remediated)
      end
    end
    let!(:old_double_success_de_remediated) do
      Timecop.freeze(olden_times) do
        create(:form526_submission, :with_submitted_claim_id, :backup_path, :no_longer_remediated)
      end
    end
    let!(:new_remediated_and_de_remediated) do
      sub = Timecop.freeze(modern_times) do
        create(:form526_submission, :remediated)
      end
      Timecop.freeze(modern_times + 1.hour) do
        create(:form526_submission_remediation,
               form526_submission: sub,
               lifecycle: ['i am no longer remediated'],
               success: false)
      end
      sub
    end
    let!(:old_remediated_and_de_remediated) do
      sub = Timecop.freeze(olden_times) do
        create(:form526_submission, :remediated)
      end
      Timecop.freeze(olden_times + 1.hour) do
        create(:form526_submission_remediation,
               form526_submission: sub,
               lifecycle: ['i am no longer remediated'],
               success: false)
      end
      sub
    end

    it 'logs 526 state metrics correctly' do
      expected_log = {
        total_awaiting_backup_status: [
          new_backup_pending.id
        ].sort,
        total_incomplete_type: [
          still_running_with_retryable_errors.id,
          new_unprocessed.id,
          new_backup_pending.id,
          new_no_job_de_remediated.id,
          new_remediated_and_de_remediated.id
        ].sort,
        total_failure_type: [
          old_unprocessed.id,
          old_backup_pending.id,
          new_backup_rejected.id,
          old_backup_rejected.id,
          old_double_job_failure.id,
          old_double_job_failure_de_remediated.id,
          old_no_job_de_remediated.id,
          old_remediated_and_de_remediated.id,
          new_double_job_failure.id,
          new_double_job_failure_de_remediated.id
        ].sort
      }

      expect(described_class.new.snapshot_state).to eq(expected_log)
    end

    it 'writes counts as Stats D gauges' do
      prefix = described_class::STATSD_PREFIX

      expect(StatsD).to receive(:gauge).with("#{prefix}.total_awaiting_backup_status_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.total_incomplete_type_count", 5)
      expect(StatsD).to receive(:gauge).with("#{prefix}.total_failure_type_count", 10)

      described_class.new.perform
    end
  end
end
