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
      in_progress_new_0781: InProgressForm.where(form_id: '21-526EZ')
        .select { |ipf| JSON.parse(ipf.form_data)['view:mental_health_workflow_choice'] == 'optForOnlineForm0781' }
        .map(&:id).sort,
      
      submissions_new_0781: Form526Submission
        .select { |sub| JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2') }
        .map(&:id).sort,
      
      successful_submissions_new_0781: Form526Submission
        .select do |sub|
          next unless JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2')
          job_statuses = sub.form526_job_statuses.where(job_class: 'SubmitForm0781')
          job_statuses.first&.success?
        end.map(&:id).sort,
      
      failed_submissions_new_0781: Form526Submission
        .select do |sub|
          next unless JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2')
          job_statuses = sub.form526_job_statuses.where(job_class: 'SubmitForm0781')
          Form526JobStatus::FAILURE_STATUSES.include?(job_statuses.first&.status)
        end.map(&:id).sort,
      
      primary_path_submissions_new_0781: Form526Submission.where.not(submitted_claim_id: nil)
        .select { |sub| JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2') }
        .map(&:id).sort,
      
      secondary_path_submissions_new_0781: Form526Submission.where(submitted_claim_id: nil)
        .select { |sub| JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2') }
        .map(&:id).sort,
      
      # Old 0781 form metrics
      in_progress_old_0781: InProgressForm.where(form_id: '21-526EZ')
        .select { |ipf| !JSON.parse(ipf.form_data)['view:selectable_ptsd_types']&.values&.all?(false) }
        .map(&:id).sort,
      
      submissions_old_0781: Form526Submission
        .select { |sub| !JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2') }
        .map(&:id).sort,
      
      successful_submissions_old_0781: Form526Submission
        .select do |sub|
          next if JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2')
          job_statuses = sub.form526_job_statuses.where(job_class: 'SubmitForm0781')
          job_statuses.first&.success?
        end.map(&:id).sort,
      
      failed_submissions_old_0781: Form526Submission
        .select do |sub|
          next if JSON.parse(sub.form_to_json(Form526Submission::FORM_0781))&.keys&.include?('form0781v2')
          job_statuses = sub.form526_job_statuses.where(job_class: 'SubmitForm0781')
          Form526JobStatus::FAILURE_STATUSES.include?(job_statuses.first&.status)
        end.map(&:id).sort
    }
  end
end
