# frozen_string_literal: true

FactoryBot.define do
  factory :form526_job_status do
    form526_submission_id { 123 }
    job_id { SecureRandom.hex(12) }
    job_class { 'SubmitForm526AllClaim' }
    status { 'success' }
    error_class { nil }
    error_message { nil }
    bgjob_errors { {} }
  end

  trait :retryable_error do
    status { 'retryable_error' }
    error_class { 'Common::Exceptions::GatewayTimeout' }
    error_message { 'Did not receive a timely response from an upstream server' }
    bgjob_errors do
      {
        error_class: 'Common::Exceptions::GatewayTimeout',
        error_message: 'Did not receive a timely response from an upstream server',
        timestamp: Time.now.utc
      }
    end
  end

  trait :non_retryable_error do
    status { 'non_retryable_error' }
    error_class { 'NoMethodError' }
    error_message { 'undefined method foo for nil class' }
    bgjob_errors do
      {
        error_class: 'NoMethodError',
        error_message: 'undefined method foo for nil class',
        timestamp: Time.now.utc
      }
    end
  end
end
