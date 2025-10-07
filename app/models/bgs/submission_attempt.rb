# frozen_string_literal: true

class BGS::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'bgs_submission_attempts'

  include SubmissionAttemptEncryption

  belongs_to :submission, class_name: 'BGS::Submission', foreign_key: :bgs_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission

  enum :status, {
    pending: 'pending',
    submitted: 'submitted',
    failure: 'failure'
  }

  STATS_KEY = 'api.bgs.submission_attempt'

  def fail!
    failure!
    log_hash = status_change_hash
    log_hash[:message] = 'BGS Submission Attempt failed'
    monitor.track_request(:error, log_hash[:message], STATS_KEY, **log_hash)
  end

  def manual!
    manually!
    log_hash = status_change_hash
    log_hash[:message] = 'BGS Submission Attempt is being manually remediated'
    monitor.track_request(:warn, log_hash[:message], STATS_KEY, **log_hash)
  end

  def pending!
    update(status: :pending)
    log_hash = status_change_hash
    log_hash[:message] = 'BGS Submission Attempt is pending'
    monitor.track_request(:info, log_hash[:message], STATS_KEY, **log_hash)
  end

  def success!
    submitted!
    log_hash = status_change_hash
    log_hash[:message] = 'BGS Submission Attempt is submitted'
    monitor.track_request(:info, log_hash[:message], STATS_KEY, **log_hash)
  end

  def monitor
    @monitor ||= Logging::Monitor.new('bgs_submission_attempt')
  end
end
