# frozen_string_literal: true

FactoryBot.define do
  factory :form526_submission do
    user_uuid { SecureRandom.uuid }
    saved_claim { create(:va526ez) }
    submitted_claim_id { nil }
    auth_headers_json { 'null' }
    form_json do
      File.read("#{::Rails.root}/spec/support/disability_compensation_form/submissions/only_526.json")
    end
  end

  trait :with_uploads do
    form_json do
      File.read("#{::Rails.root}/spec/support/disability_compensation_form/submissions/with_uploads.json")
    end
  end

  trait :with_one_succesful_job do
    after(:create) do |submission|
      create(:form526_job_status, form526_submission: submission)
    end
  end

  trait :with_multiple_succesful_jobs do
    after(:create) do |submission|
      create(:form526_job_status, form526_submission: submission)
      create(:form526_job_status, job_class: 'SubmitUploads', form526_submission: submission)
    end
  end

  trait :with_mixed_status do
    after(:create) do |submission|
      create(:form526_job_status, form526_submission: submission)
      create(:form526_job_status, :retryable_error, job_class: 'SubmitUploads', form526_submission: submission)
    end
  end

  trait :with_one_failed_job do
    after(:create) do |submission|
      create(:form526_job_status, :retryable_error, form526_submission: submission)
    end
  end
end
