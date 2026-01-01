# frozen_string_literal: true

# Log information about Form 526 new conditions workflow in-progress forms to populate a Datadog dashboard
class Form526NewConditionsStateSnapshotJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATSD_PREFIX = 'form526.new_conditions.state.snapshot'

  def perform
    if Flipper.enabled?(:disability_compensation_new_conditions_stats_job)
      write_snapshot
    else
      Rails.logger.info('New conditions state snapshot job disabled',
                        class: self.class.name,
                        message: 'Flipper flag disability_compensation_new_conditions_stats_job is disabled')
    end
  rescue => e
    Rails.logger.error('Error logging new conditions state snapshot',
                       class: self.class.name,
                       message: e.try(:message))
  end

  private

  def write_snapshot
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
    @snapshot_state ||= {
      v2_in_progress_forms:,
      v1_in_progress_forms:,
      total_in_progress_forms:
    }
  end

  # V2 forms - those with new_conditions_workflow metadata set to 'true'
  def v2_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ').where("metadata->>'new_conditions_workflow' = 'true'").pluck(:id)
  end

  # V1 forms - those WITHOUT new_conditions_workflow metadata key
  def v1_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ').where.not("metadata::jsonb ? 'new_conditions_workflow'").pluck(:id)
  end

  # Total 526 in-progress forms (regardless of workflow version)
  def total_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ').pluck(:id)
  end
end
