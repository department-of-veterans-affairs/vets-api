# frozen_string_literal: true

FactoryBot.define do
  factory :form526_submission do
    user_uuid '123'
    saved_claim_id '123'
    submitted_claim_id nil
    auth_headers_json ''
    form_json do
      File.read("#{::Rails.root}/spec/support/disability_compensation_form/submissions/only_526.json")
    end
  end

  trait :with_uploads do
    form_json do
      File.read("#{::Rails.root}/spec/support/disability_compensation_form/submissions/with_uploads.json")
    end
  end
end
