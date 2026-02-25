# frozen_string_literal: true

FactoryBot.define do
  factory :multi_party_form_submission do
    form_type { '21-2680' }
    primary_user_uuid { SecureRandom.uuid }

    primary_in_progress_form do
      association :in_progress_form, form_id: "#{form_type}-PRIMARY"
    end

    trait :with_secondary do
      secondary_email { 'test@example.com' }
    end
  end
end
