# frozen_string_literal: true

FactoryBot.define do
  factory :multi_party_form_submission do
    form_type { '21-2680' }
    primary_user_uuid { SecureRandom.uuid }

    association :primary_in_progress_form, factory: :in_progress_form, form_id: '21-2680'

    trait :with_secondary do
      secondary_email { 'test@example.com' }
    end
  end
end
