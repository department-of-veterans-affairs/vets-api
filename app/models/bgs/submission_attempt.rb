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

  scope :by_claim_group, lambda { |parent_claim_id|
    joins(submission: { saved_claim: :child_of_groups })
      .where(saved_claim_groups: { parent_claim_id: })
  }

  STATS_KEY = 'api.bgs.submission_attempt'

  def fail!(error:)
    update(error_message: error&.message)
    failure!
    log_hash = status_change_hash
    log_hash[:message] = 'BGS Submission Attempt failed'
    monitor.track_request(:error, log_hash[:message], STATS_KEY, **log_hash)
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

  def claim_type_end_product
    data = metadata.present? ? JSON.parse(metadata) : {}
    data['claim_type_end_product']
  end

  def monitor
    @monitor ||= Logging::Monitor.new('bgs_submission_attempt')
  end

  def status_change_hash
    {
      submission_id: submission.id,
      claim_id: submission.saved_claim_id,
      form_type: submission.form_id,
      from_state: previous_changes[:status]&.first,
      to_state: status
    }
  end
end
