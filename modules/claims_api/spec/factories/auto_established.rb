# frozen_string_literal: true

FactoryBot.define do
  factory :auto_established, class: 'ClaimsApi::AutoEstablishedClaim' do
    status { 'pending' }
    source { 'oddball' }
    auth_headers { { test: ('a'..'z').to_a.shuffle.join } }
    form_data { { test: ('a'..'z').to_a.shuffle.join } }

    trait :status_established do
      status { 'established' }
    end

    trait :status_errored do
      status { 'errored' }
      evss_response { ['something'] }
    end
  end
end
