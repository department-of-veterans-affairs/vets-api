# frozen_string_literal: true

# Log information about Form 0781 submissions to populate an admin facing Datadog dashboard
class Form0781StateSnapshotJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATSD_PREFIX = 'form0781.state.snapshot'
  ROLLOUT_DATE = Date.new(2025, 4, 2)

  def perform
    if Flipper.enabled?(:disability_compensation_0781_stats_job)
      write_0781_snapshot
    else
      Rails.logger.info('0781 state snapshot job disabled',
                        class: self.class.name,
                        message: 'Flipper flag disability_compensation_0781_stats_job is disabled')
    end
  rescue => e
    Rails.logger.error('Error logging 0781 state snapshot',
                       class: self.class.name,
                       message: e.try(:message))
  end

  def write_0781_snapshot
    state_as_counts.each do |description, count|
      StatsD.gauge("#{STATSD_PREFIX}.#{description}", count)
    end
  end

  def state_as_counts
    @state_as_counts ||= {}.tap do |abbreviation|
      snapshot_state.each do |dp, ids|
        abbreviation[:"#{dp}_count"] = ids.count
      end
    end
  end

  def snapshot_state
    @snapshot_state ||= load_snapshot_state
  end

  def load_snapshot_state
    {
      # New 0781 form metrics
      new_0781_in_progress_forms:,
      new_0781_submissions:,
      new_0781_successful_submissions:,
      new_0781_failed_submissions:,
      new_0781_primary_path_submissions:,
      new_0781_secondary_path_submissions:,

      # Old 0781 form metrics
      old_0781_in_progress_forms:,
      old_0781_submissions:,
      old_0781_successful_submissions:,
      old_0781_failed_submissions:
    }
  end

  # Helper methods for new 0781 form metrics
  def new_0781_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ')
                  .select { |ipf| new_mental_health_workflow?(ipf) }
                  .pluck(:id)
  end

  def new_mental_health_workflow?(ipf)
    JSON.parse(ipf.form_data)['view:mental_health_workflow_choice'] == 'optForOnlineForm0781'
  end

  def new_0781_submissions
    form526_submissions
      .where('created_at >= ?', ROLLOUT_DATE)
      .select { |sub| new_0781_form?(sub) }
      .pluck(:id)
  end

  def new_0781_successful_submissions
    form526_submissions
      .where('created_at >= ?', ROLLOUT_DATE)
      .select do |sub|
        next unless new_0781_form?(sub)

        form0781_job_success?(sub)
      end.pluck(:id)
  end

  def new_0781_failed_submissions
    form526_submissions
      .where('created_at >= ?', ROLLOUT_DATE)
      .select do |sub|
        next unless new_0781_form?(sub)

        form0781_job_failure?(sub)
      end.pluck(:id)
  end

  def new_0781_primary_path_submissions
    form526_submissions.where('created_at >= ?', ROLLOUT_DATE)
                       .where.not(submitted_claim_id: nil)
                       .select { |sub| new_0781_form?(sub) }
                       .pluck(:id)
  end

  def new_0781_secondary_path_submissions
    form526_submissions.where('created_at >= ?', ROLLOUT_DATE)
                       .where(submitted_claim_id: nil)
                       .select { |sub| new_0781_form?(sub) }
                       .pluck(:id)
  end

  # Helper methods for old 0781 form metrics
  def old_0781_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ')
                  .select { |ipf| old_ptsd_types_selected?(ipf) }
                  .pluck(:id)
  end

  def old_ptsd_types_selected?(ipf)
    !JSON.parse(ipf.form_data)['view:selectable_ptsd_types']&.values&.all?(false)
  end

  def old_0781_submissions
    form526_submissions
      .where('created_at >= ?', ROLLOUT_DATE)
      .reject { |sub| new_0781_form?(sub) }
      .pluck(:id)
  end

  def old_0781_successful_submissions
    form526_submissions
      .where('created_at >= ?', ROLLOUT_DATE)
      .select do |sub|
        next if new_0781_form?(sub)

        form0781_job_success?(sub)
      end.pluck(:id)
  end

  def old_0781_failed_submissions
    form526_submissions
      .where('created_at >= ?', ROLLOUT_DATE)
      .select do |sub|
        next if new_0781_form?(sub)

        form0781_job_failure?(sub)
      end.pluck(:id)
  end

  # Common helper methods
  def form526_submissions
    @form526_submissions ||= Form526Submission.all
  end

  def new_0781_form?(submission)
    JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2')
  end

  def form0781_job_success?(submission)
    job_statuses = submission.form526_job_statuses.where(job_class: 'SubmitForm0781')
    job_statuses.first&.success?
  end

  def form0781_job_failure?(submission)
    job_statuses = submission.form526_job_statuses.where(job_class: 'SubmitForm0781')
    Form526JobStatus::FAILURE_STATUSES.include?(job_statuses.first&.status)
  end
end
