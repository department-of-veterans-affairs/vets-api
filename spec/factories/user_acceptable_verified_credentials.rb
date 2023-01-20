# frozen_string_literal: true

FactoryBot.define do
  factory :user_acceptable_verified_credential, class: 'UserAcceptableVerifiedCredential' do
    user_account { create(:user_account) }
    acceptable_verified_credential_at { Time.zone.now }
    idme_verified_credential_at { Time.zone.now }
  end
end
