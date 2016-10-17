# frozen_string_literal: true
FactoryGirl.define do
  factory :disability_claim do
    user_uuid '1234'
    evss_id   1
    data      { {} }
  end
end
