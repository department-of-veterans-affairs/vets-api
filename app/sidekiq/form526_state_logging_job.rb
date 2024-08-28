# frozen_string_literal: true

# Log information about Form526Submission state to populate an admin facing Datadog dashboard
class Form526StateLoggingJob
  include Sidekiq::Job
  sidekiq_options retry: false

  attr_reader :start_date, :end_date

  END_DATE = Time.zone.today.beginning_of_day
  START_DATE = END_DATE - 1.week

  def initialize(start_date: START_DATE, end_date: END_DATE)
    @start_date = start_date
    @end_date = end_date
  end

  def perform
    Rails.logger.info('Form 526 State Data',
                      state_log: abbreviated_state_log,
                      start_date:,
                      end_date:)
  rescue => e
    Rails.logger.error('Error logging 526 state data',
                       class: self.class.name,
                       message: e.try(:message),
                       start_date:,
                       end_date:)
  end

  def state_log
    timeboxed_state.merge(all_time_state)
  end

  def abbreviated_state_log
    {}.tap do |abbreviation|
      state_log.each do |dp, ids|
        abbreviation[:"#{dp}_count"] = ids.count
      end
      abbreviation[:total_failure_type_ids] = total_failure_type
    end
  end

  def timeboxed_state
    {
      timeboxed: timeboxed_submissions.pluck(:id).sort,
      timeboxed_primary_successes: timeboxed_submissions.accepted_to_primary_path.pluck(:id).sort,
      timeboxed_exhausted_primary_job: timeboxed_submissions.with_exhausted_primary_jobs.pluck(:id).sort,
      timeboxed_exhausted_backup_job: timeboxed_submissions.with_exhausted_backup_jobs.pluck(:id).sort,
      timeboxed_incomplete_type: timeboxed_submissions.incomplete_type.pluck(:id).sort
    }
  end

  def all_time_state
    {
      total_awaiting_backup_status: Form526Submission.pending_backup.pluck(:id).sort,
      total_incomplete_type: Form526Submission.incomplete_type.pluck(:id).sort,
      total_failure_type:
    }
  end

  def total_failure_type
    @total_failure_type ||= Form526Submission.failure_type.pluck(:id).sort
  end

  def sub_arel
    @sub_arel ||= Form526Submission.arel_table
  end

  def combined_pending_types_for(submissions)
    submissions.incomplete.pluck(:id) +
      submissions.in_process.pluck(:id)
  end

  def backup_submissions
    @backup_submissions ||= timeboxed_submissions
                            .joins(:form526_job_statuses)
                            .where(form526_job_statuses: { job_class: 'BackupSubmission', status: 'success' })
  end

  def timeboxed_submissions
    @timeboxed_submissions ||= Form526Submission
                               .where(sub_arel_created_at.gt(start_date))
                               .where(sub_arel_created_at.lt(end_date))
  end

  def sub_arel_created_at
    sub_arel[:created_at]
  end
end
