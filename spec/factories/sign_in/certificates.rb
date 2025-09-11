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

    cert = OpenSSL::X509::Certificate.new.tap do |c|
      c.version    = 2
      c.serial     = rand(1_000_000)
      c.subject    = OpenSSL::X509::Name.parse("/CN=#{subject_cn}")
      c.issuer     = issuer_name
      c.public_key = key.public_key
      c.not_before = not_before
      c.not_after  = not_after
      c.sign(signer_key, OpenSSL::Digest.new('SHA256'))
    end
    [cert, key]
  end

  factory :sign_in_certificate, class: 'SignIn::Certificate' do
    transient do
      not_before  { 1.hour.ago }
      not_after   { 100.years.from_now }
      self_signed { false }
    end

    after(:build) do |certificate, t|
      if certificate.pem.blank?
        ca_cert, ca_key = if t.self_signed
                            [nil, nil]
                          else
                            build_ca.call(t.not_before - 1.day, t.not_after + 1.day)
                          end

        leaf_cert, leaf_key = build_leaf.call(ca_cert, ca_key, t.not_before, t.not_after, t.self_signed)

        certificate.pem = leaf_cert.to_pem

        certificate.define_singleton_method(:private_key) { leaf_key }
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

    trait :expiring_soon do
      transient do
        not_before { 1.month.ago }
        not_after  { 1.month.from_now }
      end
    end

    trait :expiring_later do
      transient do
        not_before { 1.month.ago }
        not_after  { 3.months.from_now }
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
