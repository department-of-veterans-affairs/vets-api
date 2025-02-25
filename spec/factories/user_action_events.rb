# frozen_string_literal: true

FactoryBot.define do
  factory :user_action_event do
    details { Faker::Lorem.sentence }
    event_type { UserActionEvent::EVENT_TYPES.sample }
    identifier { Faker::Lorem.word }
  end
end
