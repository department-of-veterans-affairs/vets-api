# frozen_string_literal: true

# Log information about Form 0781 submissions to populate an admin facing Datadog dashboard
class Form0781StateSnapshotJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATSD_PREFIX = 'form0781.state.snapshot'

  def perform
    write_0781_snapshot
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
      in_progress_new_0781_forms: new_0781_in_progress_forms,
      submissions_new_0781_forms: new_0781_submissions,
      successful_submissions_new_0781_forms: new_0781_successful_submissions,
      failed_submissions_new_0781_forms: new_0781_failed_submissions,
      primary_path_submissions_new_0781_forms: new_0781_primary_path_submissions,
      secondary_path_submissions_new_0781_forms: new_0781_secondary_path_submissions,

      # Old 0781 form metrics
      in_progress_old_0781_forms: old_0781_in_progress_forms,
      submissions_old_0781_forms: old_0781_submissions,
      successful_submissions_old_0781_forms: old_0781_successful_submissions,
      failed_submissions_old_0781_forms: old_0781_failed_submissions
    }
  end

  # Helper methods for new 0781 form metrics
  def new_0781_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ')
                  .select { |ipf| new_mental_health_workflow?(ipf) }
                  .map(&:id).sort
  end

  def new_mental_health_workflow?(ipf)
    JSON.parse(ipf.form_data)['view:mental_health_workflow_choice'] == 'optForOnlineForm0781'
  end

  def new_0781_submissions
    Form526Submission
      .select { |sub| new_0781_form?(sub) }
      .map(&:id).sort
  end

  def new_0781_successful_submissions
    Form526Submission
      .select do |sub|
        next unless new_0781_form?(sub)

        form0781_job_success?(sub)
      end.map(&:id).sort
  end

  def new_0781_failed_submissions
    Form526Submission
      .select do |sub|
        next unless new_0781_form?(sub)

        form0781_job_failure?(sub)
      end.map(&:id).sort
  end

  def new_0781_primary_path_submissions
    Form526Submission.where.not(submitted_claim_id: nil)
                     .select { |sub| new_0781_form?(sub) }
                     .map(&:id).sort
  end

  def new_0781_secondary_path_submissions
    Form526Submission.where(submitted_claim_id: nil)
                     .select { |sub| new_0781_form?(sub) }
                     .map(&:id).sort
  end

  # Helper methods for old 0781 form metrics
  def old_0781_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ')
                  .select { |ipf| old_ptsd_types_selected?(ipf) }
                  .map(&:id).sort
  end

  def old_ptsd_types_selected?(ipf)
    !JSON.parse(ipf.form_data)['view:selectable_ptsd_types']&.values&.all?(false)
  end

  def old_0781_submissions
    Form526Submission
      .reject { |sub| new_0781_form?(sub) }
      .map(&:id).sort
  end

  def old_0781_successful_submissions
    Form526Submission
      .select do |sub|
        next if new_0781_form?(sub)

        form0781_job_success?(sub)
      end.map(&:id).sort
  end

  def old_0781_failed_submissions
    Form526Submission
      .select do |sub|
        next if new_0781_form?(sub)

        form0781_job_failure?(sub)
      end.map(&:id).sort
  end

  # Common helper methods
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
