# frozen_string_literal: true

class Lighthouse::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'lighthouse_submission_attempts'

  include SubmissionAttemptEncryption

  belongs_to :submission, class_name: 'Lighthouse::Submission', foreign_key: :lighthouse_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission

  enum :status, {
    pending: 'pending',
    submitted: 'submitted',
    vbms: 'vbms',
    failure: 'failure',
    manually: 'manually'
  }

  STATS_KEY = 'api.lighthouse.submission_attempt'

  def fail!
    failure!
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt failed'
    monitor.track_request(:error, log_hash[:message], STATS_KEY, **log_hash)
  end

  def manual!
    manually!
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt is being manually remediated'
    monitor.track_request(:warn, log_hash[:message], STATS_KEY, **log_hash)
  end

  def vbms!
    update(status: :vbms)
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt went to vbms'
    monitor.track_request(:info, log_hash[:message], STATS_KEY, **log_hash)
  end

  def pending!
    update(status: :pending)
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt is pending'
    monitor.track_request(:info, log_hash[:message], STATS_KEY, **log_hash)
  end

  def success!
    submitted!
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt is submitted'
    monitor.track_request(:info, log_hash[:message], STATS_KEY, **log_hash)
  end

  def monitor
    @monitor ||= Logging::Monitor.new('lighthouse_submission_attempt')
  end

  def status_change_hash
    {
      submission_id: submission.id,
      claim_id: submission.saved_claim_id,
      form_type: submission.form_id,
      from_state: previous_changes[:status]&.first,
      to_state: status,
      benefits_intake_uuid:
    }
  end
end
