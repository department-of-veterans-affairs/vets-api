# frozen_string_literal: true

FactoryBot.define do
  factory :form526_submission do
    user_uuid '123'
    saved_claim_id '123'
    submitted_claim_id nil
    data do
      File.read("#{::Rails.root}/spec/support/disability_compensation_form/front_end_submission_with_uploads.json")
    end
  end
end
