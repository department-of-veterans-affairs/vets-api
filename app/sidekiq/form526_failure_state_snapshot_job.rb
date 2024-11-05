# frozen_string_literal: true

# Log information about Form526Submission state to populate an admin facing Datadog dashboard
class Form526FailureStateSnapshotJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATSD_PREFIX = 'form526.state.snapshot'

  def perform
    write_failure_snapshot
  rescue => e
    Rails.logger.error('Error logging 526 state snapshot',
                       class: self.class.name,
                       message: e.try(:message))
  end

  def write_failure_snapshot
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
      total_awaiting_backup_status: Form526Submission.pending_backup.pluck(:id).sort,
      total_incomplete_type: Form526Submission.incomplete_type.pluck(:id).sort,
      total_failure_type: Form526Submission.failure_type.pluck(:id).sort
    }
  end
end
