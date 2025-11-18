# frozen_string_literal: true

FactoryBot.define do
  factory :bgs_submission_attempt, class: 'BGS::SubmissionAttempt' do
    association :submission, factory: :bgs_submission
    status { 'pending' }
    metadata do
      {
        'form_id' => '21-686C',
        'submission_type' => 'bgs',
        'submitted_at' => Time.current.iso8601,
        'claim_type_end_product' => '134'
      }
    end

    trait :without_ep do
      metadata do
        {
          'form_id' => '21-686C',
          'submission_type' => 'bgs',
          'submitted_at' => Time.current.iso8601
        }
      end
    end

    trait :pending do
      status { 'pending' }
    end

    trait :submitted do
      status { 'submitted' }
      submitted_at { 1.hour.ago }
      bgs_claim_id { '12345678' }
      response do
        {
          'claim_id' => '12345678',
          'success' => true,
          'message' => 'Successfully submitted to BGS'
        }
      end
    end

    trait :failure do
      status { 'failure' }
      error_message do
        {
          'error_class' => 'BGS::ServiceError',
          'error_message' => 'BGS service unavailable',
          'backtrace' => ['app/models/bgs/submission.rb:1']
        }
      end
    end

    trait :with_bgs_claim_id do
      bgs_claim_id { '98765432' }
    end

    trait :with_detailed_response do
      response do
        {
          'claim_id' => '12345678',
          'participant_id' => '987654321',
          'veteran_file_number' => '123456789',
          'status' => 'success',
          'timestamp' => Time.current.iso8601,
          'benefit_type' => 'compensation'
        }
      end
    end

    trait :with_detailed_error do
      error_message do
        {
          'error_class' => 'BGS::InvalidVeteranError',
          'error_message' => 'Veteran not found in BGS system',
          'error_code' => 'VET_NOT_FOUND',
          'participant_id' => '123456789',
          'file_number' => '987654321',
          'timestamp' => Time.current.iso8601,
          'backtrace' => [
            'app/models/bgs/submission.rb:1',
            'lib/bgs/services.rb:45'
          ]
        }
      end
    end

    trait :old do
      created_at { 1.week.ago }
    end

    trait :recent do
      created_at { 1.hour.ago }
    end
  end
end
