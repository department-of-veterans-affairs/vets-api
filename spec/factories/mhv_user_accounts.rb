# frozen_string_literal: true

FactoryBot.define do
  factory :mhv_user_account do
    user_profile_id { '12345678' }
    premium { true }
    champ_va { true }
    patient { true }
    sm_account_created { true }
    message { 'Success' }
  end
end
