# frozen_string_literal: true

FactoryBot.define do
  factory :form4142_status_polling_record do
    benefits_intake_uuid { 'MyString' }
    submission_id { 1 }
    submission_class { 'Form526Submission'}
    status { 1 }
  end
end
