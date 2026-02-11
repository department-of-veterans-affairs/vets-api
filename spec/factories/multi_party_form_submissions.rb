# frozen_string_literal: true

FactoryBot.define do
  factory :multi_party_form_submission do
    form_type { '21-2680' }
    primary_user_uuid { SecureRandom.uuid }
    status { 'primary_in_progress' }
    secondary_email { nil }

    trait :with_primary_completed do
      status { 'awaiting_secondary_completion' }
      primary_completed_at { Time.current }
      secondary_email { 'physician@example.com' }
      secondary_notified_at { Time.current }
    end

    trait :with_secondary_completed do
      status { 'awaiting_primary_review' }
      primary_completed_at { 1.day.ago }
      secondary_email { 'physician@example.com' }
      secondary_notified_at { 1.day.ago }
      secondary_completed_at { Time.current }
    end

    trait :submitted do
      status { 'submitted' }
      primary_completed_at { 2.days.ago }
      secondary_completed_at { 1.day.ago }
      submitted_at { Time.current }
      secondary_email { 'physician@example.com' }
    end

    trait :with_primary_in_progress_form do
      association :primary_in_progress_form, factory: :in_progress_form
    end

    trait :with_secondary_in_progress_form do
      association :secondary_in_progress_form, factory: :in_progress_form
    end
  end
end
