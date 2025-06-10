# frozen_string_literal: true

require 'json_marshal/marshaller'

class Lighthouse::SubmissionAttempt < SubmissionAttempt
  serialize :reference_data, coder: JsonMarshal::Marshaller
  serialize :metadata, coder: JsonMarshal::Marshaller
  serialize :error_message, coder: JsonMarshal::Marshaller
  serialize :response, coder: JsonMarshal::Marshaller

  self.table_name = 'lighthouse_submission_attempts'

  has_kms_key
  has_encrypted :reference_data, key: :kms_key, **lockbox_options
  has_encrypted :metadata, key: :kms_key, **lockbox_options
  has_encrypted :error_message, key: :kms_key, **lockbox_options
  has_encrypted :response, key: :kms_key, **lockbox_options

  belongs_to :submission, class_name: 'Lighthouse::Submission', foreign_key: :lighthouse_submission_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission

  enum status: {
    pending: 'pending',
    submitted: 'submitted',
    vbms: 'vbms',
    failure: 'failure',
    manually: 'manually'
  }

  def fail!
    failure!
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt failed'
    Rails.logger.public_send(:error, log_hash)
  end

  def manual!
    manually!
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt is being manually remediated'
    Rails.logger.public_send(:warn, log_hash )
  end

  def vbms!
    update(status: :vbms)
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt went to vbms'
    Rails.logger.public_send(:info, log_hash )
  end

  def pending!
    update(status: :pending)
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt is pending'
    Rails.logger.public_send(:info, log_hash)
  end

  def success!
    submitted!
    log_hash = status_change_hash
    log_hash[:message] = 'Lighthouse Submission Attempt is submitted'
    Rails.logger.public_send(:info, log_hash)
  end
end
