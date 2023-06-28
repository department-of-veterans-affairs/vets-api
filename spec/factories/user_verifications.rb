# frozen_string_literal: true

FactoryBot.define do
  factory :user_verification, class: 'UserVerification' do
    user_account { create(:user_account) }
    idme_uuid { Faker::Internet.uuid }
    logingov_uuid { nil }
    dslogon_uuid { nil }
    mhv_uuid { nil }
    backing_idme_uuid { nil }
    verified_at { Time.zone.now }
  end

  factory :idme_user_verification, class: 'UserVerification' do
    user_account { create(:user_account) }
    idme_uuid { Faker::Internet.uuid }
    logingov_uuid { nil }
    dslogon_uuid { nil }
    mhv_uuid { nil }
    backing_idme_uuid { nil }
    verified_at { Time.zone.now }
  end

  factory :logingov_user_verification, class: 'UserVerification' do
    user_account { create(:user_account) }
    idme_uuid { nil }
    logingov_uuid { Faker::Internet.uuid }
    dslogon_uuid { nil }
    mhv_uuid { nil }
    backing_idme_uuid { nil }
    verified_at { Time.zone.now }
  end

  factory :dslogon_user_verification, class: 'UserVerification' do
    user_account { create(:user_account) }
    user_credential_email { create(:user_credential_email) }
    idme_uuid { nil }
    logingov_uuid { nil }
    dslogon_uuid { Faker::Number.number(digits: 10) }
    mhv_uuid { nil }
    backing_idme_uuid { Faker::Internet.uuid }
    verified_at { Time.zone.now }
  end

  factory :mhv_user_verification, class: 'UserVerification' do
    user_account { create(:user_account) }
    idme_uuid { nil }
    logingov_uuid { nil }
    dslogon_uuid { nil }
    mhv_uuid { Faker::Internet.uuid }
    backing_idme_uuid { Faker::Internet.uuid }
    verified_at { Time.zone.now }
  end
end
