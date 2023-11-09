# frozen_string_literal: true

FactoryBot.define do
  factory :terms_of_use_agreement do
    association :user_account
    agreement_version { 'v1' }
    response { 'accepted' }
  end
end
