# frozen_string_literal: true

FactoryBot.define do
  build_ca = lambda do |not_before, not_after|
    key  = OpenSSL::PKey::RSA.new(2048)
    name = OpenSSL::X509::Name.parse('/CN=Test CA')
    cert = OpenSSL::X509::Certificate.new.tap do |c|
      c.version    = 2
      c.serial     = rand(1_000_000)
      c.subject    = name
      c.issuer     = name
      c.public_key = key.public_key
      c.not_before = not_before
      c.not_after  = not_after
      c.sign(key, OpenSSL::Digest.new('SHA256'))
    end
    [cert, key]
  end

  build_leaf = lambda do |ca_cert, ca_key, not_before, not_after, self_signed|
    key = OpenSSL::PKey::RSA.new(2048)
    subject_cn = 'Leaf Cert'
    issuer_name = if self_signed
                    OpenSSL::X509::Name.parse("/CN=#{subject_cn}")
                  else
                    ca_cert.subject
                  end
    signer_key = self_signed ? key : ca_key

    OpenSSL::X509::Certificate.new.tap do |c|
      c.version    = 2
      c.serial     = rand(1_000_000)
      c.subject    = OpenSSL::X509::Name.parse("/CN=#{subject_cn}")
      c.issuer     = issuer_name
      c.public_key = key.public_key
      c.not_before = not_before
      c.not_after  = not_after
      c.sign(signer_key, OpenSSL::Digest.new('SHA256'))
    end
  end

  factory :sign_in_certificate, class: 'SignIn::Certificate' do
    transient do
      not_before  { 1.hour.ago }
      not_after   { 100.years.from_now }
      self_signed { false }
    end

    pem do
      if self_signed
        build_leaf.call(nil, nil, not_before, not_after, true).to_pem
      else
        ca_cert, ca_key = build_ca.call(not_before - 1.day, not_after + 1.day)
        build_leaf.call(ca_cert, ca_key, not_before, not_after, false).to_pem
      end
    end

    trait :self_signed do
      transient { self_signed { true } }
    end

    trait :expired do
      transient do
        not_before { 2.years.ago }
        not_after  { 1.year.ago }
      end
    end

    trait :not_yet_valid do
      transient do
        not_before { 1.day.from_now }
        not_after  { 2.days.from_now }
      end
    end

    trait :with_config_certificates do
      transient do
        config_certificates_count { 3 }
      end

      after(:build) do |certificate, evaluator|
        create_list(:sign_in_config_certificate, evaluator.config_certificates_count, cert: certificate)
      end
    end
  end
end
