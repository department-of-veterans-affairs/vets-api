# frozen_string_literal: true

FactoryBot.define do
  factory :user_acceptable_verified_credential, class: 'UserAcceptableVerifiedCredential' do
    user_account { create(:user_account) }
    acceptable_verified_credential_at { Time.zone.now }
    idme_verified_credential_at { Time.zone.now }

    trait :idme_verified_account do
      user_account { create(:idme_user_verification).user_account }
    end

    trait :logingov_verified_account do
      user_account { create(:logingov_user_verification).user_account }
    end

    trait :mhv_verified_account do
      user_account { create(:mhv_user_verification).user_account }
    end

    trait :with_avc do
      acceptable_verified_credential_at { 1.day.ago }
    end

    trait :with_ivc do
      idme_verified_credential_at { 1.day.ago }
    end

    trait :without_avc do
      acceptable_verified_credential_at { nil }
    end

    trait :without_ivc do
      idme_verified_credential_at { nil }
    end

    trait :without_avc_ivc do
      acceptable_verified_credential_at { nil }
      idme_verified_credential_at { nil }
    end
  end
end
