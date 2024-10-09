# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_submission do
    va_gov_submission_id { 'A6KKXuzs5tSG' }
    va_gov_submission_type { 'DecisionReview::SubmitUpload' }
    status { 1 }
    upstream_system_name { 'EVSS' }
    upstream_submission_id { 'some_long_id' }
  end
end
