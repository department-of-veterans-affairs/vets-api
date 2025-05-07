# frozen_string_literal: true

# Log information about Form 0781 submissions to populate an admin facing Datadog dashboard
class Form0781StateSnapshotJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATSD_PREFIX = 'form526.form0781.state.snapshot'
  STAT_START_DATE = Date.new(2025, 4, 1)

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
    InProgressForm.where(form_id: '21-526EZ').where("metadata->>'sync_modern0781_flow' = 'true'").pluck(:id)
  end

  def new_0781_submissions_saved_claims 
    @new_0781_submissions_saved_claims ||= SavedClaim::DisabilityCompensation::Form526AllClaim.where.not(metadata:nil)
  end

  def new_0781_submissions
    new_0781_submissions_saved_claims.pluck(:id)
  end

  def new_0781_successful_submissions
    Form526Submission.where(
      saved_claim_id: new_0781_submissions_saved_claims.pluck(:id)
    ).where('submitted_claim_id IS NOT NULL OR backup_submitted_claim_id IS NOT NULL').pluck(:id)
  end

  def new_0781_failed_submissions
    Form526Submission.where(
      saved_claim_id: new_0781_submissions_saved_claims.pluck(:id)
    ).where('submitted_claim_id IS NULL AND backup_submitted_claim_id IS NULL').pluck(:id)
  end

  def new_0781_primary_path_submissions
    Form526Submission.where(
      saved_claim_id: new_0781_submissions_saved_claims.pluck(:id)
    ).where('submitted_claim_id IS NOT NULL').pluck(:id)
  end

  def new_0781_secondary_path_submissions
    Form526Submission.where(
      saved_claim_id: new_0781_submissions_saved_claims.pluck(:id)
    ).where('backup_submitted_claim_id IS NOT NULL').pluck(:id)
  end

  # Helper methods for old 0781 form metrics
  def old_0781_in_progress_forms
    InProgressForm.where(form_id: '21-526EZ').where.not("metadata::jsonb ? 'sync_modern0781_flow'").pluck(:id)
  end

  def old_0781_submissions_saved_claims
    @old_0781_submissions_saved_claims ||= SavedClaim::DisabilityCompensation::Form526AllClaim.where(metadata:nil, created_at: new_0781_submissions_saved_claims.first.created_at..Time.current)
  end

  def old_0781_submissions
    old_0781_submissions_saved_claims.pluck(:id)
  end
  def old_0781_successful_submissions
    Form526Submission.where(
      saved_claim_id: old_0781_submissions_saved_claims.pluck(:id)
    ).where('submitted_claim_id IS NOT NULL OR backup_submitted_claim_id IS NOT NULL').pluck(:id)
  end
  def old_0781_failed_submissions
    Form526Submission.where(
      saved_claim_id: old_0781_submissions_saved_claims.pluck(:id)
    ).where('submitted_claim_id IS NULL AND backup_submitted_claim_id IS NULL').pluck(:id)
  end

end
