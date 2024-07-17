# frozen_string_literal: true

FactoryBot.define do
  factory :form526_job_status do
    association :form526_submission, factory: %i[form526_submission with_one_succesful_job]
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
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'retryable_error_handler',
          'error_class' => 'Common::Exceptions::GatewayTimeout',
          'error_message' => 'Did not receive a timely response from an upstream server',
          'timestamp' => Time.now.utc
        }
      }
    end
  end

  trait :non_retryable_error do
    status { 'non_retryable_error' }
    error_class { 'NoMethodError' }
    error_message { 'undefined method foo for nil class' }
    bgjob_errors do
      {
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'non_retryable_error_handler',
          'error_class' => 'NoMethodError',
          'error_message' => 'undefined method foo for nil class',
          'timestamp' => Time.now.utc
        }
      }
    end
  end

  trait :exhausted_backup_job do
    job_class { 'BackupSubmission' }
    status { 'exhausted' }
    error_class { 'EVSS::DisabilityCompensationForm::ServiceException' }
    error_message { 'PIF in use' }
    bgjob_errors do
      {
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'job_try',
          'timestamp' => '2021-11-09T15:55:58.639Z',
          'error_class' => nil,
          'error_message' => nil
        },
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'job_exhausted',
          'timestamp' => '2021-11-09T15:56:05.708Z',
          'error_class' => 'EVSS::DisabilityCompensationForm::ServiceException',
          'error_message' => 'PIF in use'
        },
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'retryable_error_handler',
          'timestamp' => '2021-11-09T15:56:05.702Z',
          'error_class' => {},
          'error_message' => '[{"key"=>"form526.submit.save.draftForm.PIFInUse", "severity"=>"FATAL", ' \
                             '"text"=>"Claim could not be established. Contact the BDN team and have them run the ' \
                             'WIPP process to delete Cancelled/Cleared PIFs"}]'
        }
      }
    end
  end

  trait :pif_in_use_error do
    job_class { 'SubmitForm526AllClaim' }
    status { 'exhausted' }
    error_class { 'EVSS::DisabilityCompensationForm::ServiceException' }
    error_message { 'PIF in use' }
    bgjob_errors do
      {
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'job_try',
          'timestamp' => '2021-11-09T15:55:58.639Z',
          'error_class' => nil,
          'error_message' => nil
        },
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'job_exhausted',
          'timestamp' => '2021-11-09T15:56:05.708Z',
          'error_class' => 'EVSS::DisabilityCompensationForm::ServiceException',
          'error_message' => 'PIF in use'
        },
        Time.now.utc.to_i.to_s => {
          'caller_method' => 'retryable_error_handler',
          'timestamp' => '2021-11-09T15:56:05.702Z',
          'error_class' => {},
          'error_message' => '[{"key"=>"form526.submit.save.draftForm.PIFInUse", "severity"=>"FATAL", ' \
                             '"text"=>"Claim could not be established. Contact the BDN team and have them run the ' \
                             'WIPP process to delete Cancelled/Cleared PIFs"}]'
        }
      }
    end
  end

  trait :poll_form526_pdf do
    status { 'try' }
    error_class { nil }
    error_message { nil }
    bgjob_errors { nil }
  end

  trait :backup_path_job do
    after(:create) do |job|
      job.update!(job_class: 'BackupSubmission')
    end
  end
end
