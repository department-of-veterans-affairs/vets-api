# frozen_string_literal: true

FactoryBot.define do
  factory :form_intake_submission do
    association :form_submission
    benefits_intake_uuid { SecureRandom.uuid }
    aasm_state { 'pending' }
    retry_count { 0 }

    trait :pending do
      aasm_state { 'pending' }
    end

    trait :submitted do
      aasm_state { 'submitted' }
      submitted_at { Time.current }
    end

    trait :success do
      aasm_state { 'success' }
      submitted_at { 1.hour.ago }
      completed_at { Time.current }
    end

    trait :failed do
      aasm_state { 'failed' }
      submitted_at { 1.hour.ago }
      completed_at { Time.current }
      error_message { 'API request failed' }
    end

    trait :with_request_payload do
      request_payload { { form_type: '21P-0537', data: { test: 'value' } }.to_json }
    end

    trait :with_response do
      response { { status: 'ok', id: SecureRandom.uuid }.to_json }
    end

    trait :with_error do
      error_message { 'Connection timeout after 30 seconds' }
    end

    trait :with_retries do
      retry_count { 3 }
      last_attempted_at { 5.minutes.ago }
    end

    trait :stale do
      aasm_state { 'pending' }
      created_at { 2.days.ago }
      retry_count { 5 }
      last_attempted_at { 1.day.ago }
    end
  end
end
