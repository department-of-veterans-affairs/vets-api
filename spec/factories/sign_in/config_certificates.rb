# frozen_string_literal: true

FactoryBot.define do
  factory :sign_in_config_certificate, class: 'SignIn::ConfigCertificate' do
    for_client_config
    association :cert, factory: :sign_in_certificate

    trait :for_client_config do
      association :config, factory: :client_config
    end

    trait :for_service_account_config do
      association :config, factory: :service_account_config
    end
  end
end
