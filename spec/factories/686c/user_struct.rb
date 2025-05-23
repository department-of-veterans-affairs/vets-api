# frozen_string_literal: true

FactoryBot.define do
  factory :user_struct, class: OpenStruct do
    first_name { 'WESLEY' }
    last_name { 'FORD' }
    middle_name { nil }
    ssn { '796043735' }
    email { Faker::Internet.email }
    va_profile_email { Faker::Internet.email }
    participant_id { '600061742' }
    icn { '82836359962678900' }
    uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
    common_name { 'WES' }
  end
end
