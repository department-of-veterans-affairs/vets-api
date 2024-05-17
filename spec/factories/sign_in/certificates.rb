# frozen_string_literal: true

FactoryBot.define do
  factory :sign_in_certificate, class: 'SignIn::Certificate' do
    issuer { '/C=US/ST=DC/L=Washington/O=Department of Veterans Affairs/OU=OCTO' }
    subject { '/C=US/ST=Washington/L=DC/O=Department of Veterans Affairs/OU=vets-api localhost/CN=va.gov' }
    serial { '155899904190010676188270788522204217112053295553' }
    not_before { 6.months.ago }
    not_after { 6.months.from_now }
    plaintext { File.read('spec/fixtures/sign_in/sample_configuration_certificate.crt') }
    association :client_config, factory: :client_config
    association :service_account_config, factory: :service_account_config

    trait :expired do
      to_create { |instance| instance.save(validate: false) }

      not_after { 1.day.ago }
    end

    trait :self_signed do
      to_create { |instance| instance.save(validate: false) }

      issuer { '/C=US/ST=DC/L=Washington/O=Department of Veterans Affairs/OU=OCTO' }
      subject { '/C=US/ST=DC/L=Washington/O=Department of Veterans Affairs/OU=OCTO' }
    end
  end
end
