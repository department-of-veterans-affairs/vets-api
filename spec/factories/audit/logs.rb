# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log, class: 'Audit::Log' do
    subject_user_identifier { Faker::Internet.uuid }
    subject_user_identifier_type { 'icn' }
    acting_user_identifier { Faker::Internet.uuid }
    acting_user_identifier_type { 'icn' }
    event_id { Faker::Number.non_zero_digit }
    event_description { Faker::Json.shallow_json(width: 3) }
    event_status { 'success' }
    event_occurred_at { Time.current }
    message { { 'key' => 'value' } }
  end
end
