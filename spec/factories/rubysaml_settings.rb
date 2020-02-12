# frozen_string_literal: true

FactoryBot.define do
  factory :rubysaml_settings, class: 'OneLogin::RubySaml::Settings' do
    certificate                     { Settings.saml.certificate }
    private_key                     { Settings.saml.key }
    sp_entity_id                    { Settings.saml.issuer }
    assertion_consumer_service_url  { Settings.saml.callback_url }
    authn_context                   { LOA::IDME_LOA1_VETS }
    idp_cert                        { File.read("#{::Rails.root}/spec/fixtures/files/idme_cert.crt") }
    idp_cert_fingerprint            { '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32' }
    idp_entity_id                   { 'api.idmelabs.com' }
    idp_slo_target_url              { 'https://api.idmelabs.com/saml/SingleLogoutService' }
    idp_sso_target_url              { 'https://api.idmelabs.com/saml/SingleSignOnService' }
    name_identifier_format          { 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified' }

    trait :rollover_cert do
      certificate_new { Settings.saml.certificate }
    end
  end

  factory :settings_no_context, class: 'OneLogin::RubySaml::Settings' do
    certificate                     { Settings.saml.certificate }
    private_key                     { Settings.saml.key }
    sp_entity_id                    { Settings.saml.issuer }
    assertion_consumer_service_url  { Settings.saml.callback_url }
    idp_cert                        { File.read("#{::Rails.root}/spec/fixtures/files/idme_cert.crt") }
    idp_cert_fingerprint            { '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32' }
    idp_entity_id                   { 'api.idmelabs.com' }
    idp_slo_target_url              { 'https://api.idmelabs.com/saml/SingleLogoutService' }
    idp_sso_target_url              { 'https://api.idmelabs.com/saml/SingleSignOnService' }
    name_identifier_format          { 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified' }
  end

  factory :rubysaml_settings_v1, class: 'OneLogin::RubySaml::Settings' do
    certificate                     { Settings.saml.certificate }
    private_key                     { Settings.saml.key }
    sp_entity_id                    { Settings.saml.issuer }
    assertion_consumer_service_url  { Settings.saml.callback_url }
    idp_cert                        { File.read("#{::Rails.root}/spec/fixtures/files/idme_cert.crt") }
    idp_cert_fingerprint            { '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32' }
    idp_entity_id                   { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20' }
    idp_slo_target_url              { 'https://pint.eauth.va.gov/pkmslogout' }
    idp_sso_target_url              { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login' }
    name_identifier_format          { 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified' }

    trait :rollover_cert do
      certificate_new { Settings.saml.certificate }
    end
  end

  factory :settings_no_context_v1, class: 'OneLogin::RubySaml::Settings' do
    certificate                     { Settings.saml.certificate }
    private_key                     { Settings.saml.key }
    sp_entity_id                    { Settings.saml.issuer }
    assertion_consumer_service_url  { Settings.saml.callback_url }
    idp_cert                        { File.read("#{::Rails.root}/spec/fixtures/files/idme_cert.crt") }
    idp_cert_fingerprint            { '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32' }
    idp_entity_id                   { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20' }
    idp_slo_target_url              { 'https://pint.eauth.va.gov/pkmslogout' }
    idp_sso_target_url              { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login' }
    name_identifier_format          { 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified' }
  end
end
