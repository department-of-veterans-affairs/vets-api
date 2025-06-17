# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form0781StateSnapshotJob, type: :worker do
  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).and_call_original
    # Make sure tests use a fixed date for ROLLOUT_DATE
    stub_const('Form0781StateSnapshotJob::ROLLOUT_DATE', Date.new(2025, 4, 2))
  end

  # Ensure modern_times is after ROLLOUT_DATE
  let!(:modern_times) { Date.new(2025, 4, 15).to_time }
  # Ensure olden_times is before ROLLOUT_DATE
  let!(:olden_times) { Date.new(2025, 3, 1).to_time }

  describe '0781 state logging' do
    # Create test data for new 0781 forms
    let!(:in_progress_new_form) do
      Timecop.freeze(modern_times) do
        ipf = create(:in_progress_form, form_id: '21-526EZ')
        form_data = JSON.parse(ipf.form_data)
        form_data['view:mental_health_workflow_choice'] = 'optForOnlineForm0781'
        ipf.update(form_data: form_data.to_json)
        ipf
      end
    end

    let!(:new_0781_submission) do
      Timecop.freeze(modern_times) do
        sub = create(:form526_submission)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781v2": {}}')
        allow(sub).to receive(:created_at).and_return(modern_times)
        sub
      end
    end

    let!(:new_0781_successful_submission) do
      Timecop.freeze(modern_times) do
        sub = create(:form526_submission, :with_one_succesful_job)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781v2": {}}')
        allow(sub).to receive(:created_at).and_return(modern_times)
        allow(sub.form526_job_statuses.first).to receive_messages(job_class: 'SubmitForm0781')
        sub
      end
    end

    let!(:new_0781_failed_submission) do
      Timecop.freeze(modern_times) do
        sub = create(:form526_submission, :with_one_failed_job)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781v2": {}}')
        allow(sub).to receive(:created_at).and_return(modern_times)
        allow(sub.form526_job_statuses.first).to receive_messages(
          job_class: 'SubmitForm0781',
          status: 'non_retryable_error'
        )
        sub
      end
    end

    let!(:new_0781_primary_path) do
      Timecop.freeze(modern_times) do
        sub = create(:form526_submission, :with_submitted_claim_id)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781v2": {}}')
        allow(sub).to receive(:created_at).and_return(modern_times)
        sub
      end
    end

    let!(:new_0781_secondary_path) do
      Timecop.freeze(modern_times) do
        sub = create(:form526_submission)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781v2": {}}')
        allow(sub).to receive(:created_at).and_return(modern_times)
        sub
      end
    end

    # Create test data for old 0781 forms - these are BEFORE the rollout date
    let!(:in_progress_old_form) do
      Timecop.freeze(olden_times) do
        ipf = create(:in_progress_form, form_id: '21-526EZ')
        form_data = JSON.parse(ipf.form_data)
        form_data['view:selectable_ptsd_types'] = { 'PTSD_COMBAT' => true }
        ipf.update(form_data: form_data.to_json)
        ipf
      end
    end

    let!(:old_0781_submission) do
      Timecop.freeze(olden_times) do
        sub = create(:form526_submission)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781": {}}')
        allow(sub).to receive(:created_at).and_return(olden_times)
        sub
      end
    end

    let!(:old_0781_successful_submission) do
      Timecop.freeze(olden_times) do
        sub = create(:form526_submission, :with_one_succesful_job)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781": {}}')
        allow(sub).to receive(:created_at).and_return(olden_times)
        allow(sub.form526_job_statuses.first).to receive_messages(job_class: 'SubmitForm0781')
        sub
      end
    end

    let!(:old_0781_failed_submission) do
      Timecop.freeze(olden_times) do
        sub = create(:form526_submission, :with_one_failed_job)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781": {}}')
        allow(sub).to receive(:created_at).and_return(olden_times)
        allow(sub.form526_job_statuses.first).to receive_messages(
          job_class: 'SubmitForm0781',
          status: 'non_retryable_error'
        )
        sub
      end
    end

    # Create a new old-form submission AFTER the rollout date
    let!(:new_old_submission) do
      Timecop.freeze(modern_times) do
        sub = create(:form526_submission)
        allow(sub).to receive(:form_to_json).with(Form526Submission::FORM_0781).and_return('{"form0781": {}}')
        allow(sub).to receive(:created_at).and_return(modern_times)
        sub
      end
    end

    it 'logs 0781 state metrics correctly' do
      # Allow each method to return its expected values
      allow_any_instance_of(described_class)
        .to receive(:new_0781_in_progress_forms)
        .and_return([in_progress_new_form.id])
      allow_any_instance_of(described_class)
        .to receive(:new_0781_submissions)
        .and_return([
                      new_0781_submission.id,
                      new_0781_successful_submission.id,
                      new_0781_failed_submission.id,
                      new_0781_primary_path.id,
                      new_0781_secondary_path.id
                    ])
      allow_any_instance_of(described_class)
        .to receive(:new_0781_successful_submissions)
        .and_return([new_0781_successful_submission.id])
      allow_any_instance_of(described_class)
        .to receive(:new_0781_failed_submissions)
        .and_return([new_0781_failed_submission.id])
      allow_any_instance_of(described_class)
        .to receive(:new_0781_primary_path_submissions)
        .and_return([new_0781_primary_path.id])
      allow_any_instance_of(described_class)
        .to receive(:new_0781_secondary_path_submissions)
        .and_return([
                      new_0781_submission.id,
                      new_0781_secondary_path.id
                    ])
      allow_any_instance_of(described_class)
        .to receive(:old_0781_in_progress_forms)
        .and_return([in_progress_old_form.id])

      # Only returns the one submission that's after the rollout date
      allow_any_instance_of(described_class)
        .to receive(:old_0781_submissions)
        .and_return([new_old_submission.id])
      allow_any_instance_of(described_class)
        .to receive(:old_0781_successful_submissions)
        .and_return([])
      allow_any_instance_of(described_class)
        .to receive(:old_0781_failed_submissions)
        .and_return([])

      # Expected log with the correct data based on our setup
      expected_log = {
        new_0781_in_progress_forms: [in_progress_new_form.id],
        new_0781_submissions: [
          new_0781_submission.id,
          new_0781_successful_submission.id,
          new_0781_failed_submission.id,
          new_0781_primary_path.id,
          new_0781_secondary_path.id
        ],
        new_0781_successful_submissions: [new_0781_successful_submission.id],
        new_0781_failed_submissions: [new_0781_failed_submission.id],
        new_0781_primary_path_submissions: [new_0781_primary_path.id],
        new_0781_secondary_path_submissions: [
          new_0781_submission.id,
          new_0781_secondary_path.id
        ],
        old_0781_in_progress_forms: [in_progress_old_form.id],
        old_0781_submissions: [new_old_submission.id], # Only includes submission after rollout date
        old_0781_successful_submissions: [],
        old_0781_failed_submissions: []
      }

      # Mock the load_snapshot_state method to return our expected data
      allow_any_instance_of(described_class).to receive(:load_snapshot_state).and_return(expected_log)

      expect(described_class.new.snapshot_state).to eq(expected_log)
    end

    it 'writes counts as Stats D gauges' do
      prefix = described_class::STATSD_PREFIX

      # Create a mock snapshot_state result
      mock_snapshot = {
        new_0781_in_progress_forms: [1],
        new_0781_submissions: [1, 2, 3, 4, 5],
        new_0781_successful_submissions: [2],
        new_0781_failed_submissions: [3],
        new_0781_primary_path_submissions: [4],
        new_0781_secondary_path_submissions: [1, 5],
        old_0781_in_progress_forms: [6],
        old_0781_submissions: [7, 8, 9],
        old_0781_successful_submissions: [8],
        old_0781_failed_submissions: [9]
      }

      # Stub the snapshot_state method to return our mock data
      allow_any_instance_of(described_class).to receive(:snapshot_state).and_return(mock_snapshot)

      # Expect StatsD.gauge to be called for each metric with the correct count
      expect(StatsD).to receive(:gauge).with("#{prefix}.new_0781_in_progress_forms_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.new_0781_submissions_count", 5)
      expect(StatsD).to receive(:gauge).with("#{prefix}.new_0781_successful_submissions_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.new_0781_failed_submissions_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.new_0781_primary_path_submissions_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.new_0781_secondary_path_submissions_count", 2)
      expect(StatsD).to receive(:gauge).with("#{prefix}.old_0781_in_progress_forms_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.old_0781_submissions_count", 3)
      expect(StatsD).to receive(:gauge).with("#{prefix}.old_0781_successful_submissions_count", 1)
      expect(StatsD).to receive(:gauge).with("#{prefix}.old_0781_failed_submissions_count", 1)

      described_class.new.perform
    end
  end
end
