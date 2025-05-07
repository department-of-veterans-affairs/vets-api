# frozen_string_literal: true

FactoryBot.define do
  factory :rubysaml_settings, class: 'OneLogin::RubySaml::Settings' do
    certificate                     { IdentitySettings.saml_ssoe.certificate }
    private_key                     { IdentitySettings.saml_ssoe.key }
    sp_entity_id                    { IdentitySettings.saml_ssoe.issuer }
    assertion_consumer_service_url  { IdentitySettings.saml_ssoe.callback_url }
    idp_cert                        {
      File.read(Rails.root.join(*'/spec/fixtures/files/idme_cert.crt'.split('/'))
                            .to_s)
    }
    idp_cert_fingerprint            { '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32' }
    idp_entity_id                   { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20' }
    idp_slo_target_url              { 'https://pint.eauth.va.gov/pkmslogout' }
    idp_sso_target_url              { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login' }
    name_identifier_format { 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified' }
  end

  factory :settings_no_context, class: 'OneLogin::RubySaml::Settings' do
    certificate                     { IdentitySettings.saml_ssoe.certificate }
    private_key                     { IdentitySettings.saml_ssoe.key }
    sp_entity_id                    { IdentitySettings.saml_ssoe.issuer }
    assertion_consumer_service_url  { IdentitySettings.saml_ssoe.callback_url }
    idp_cert                        {
      File.read(Rails.root.join(*'/spec/fixtures/files/idme_cert.crt'.split('/'))
                            .to_s)
    }
    idp_cert_fingerprint            { '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32' }
    idp_entity_id                   { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20' }
    idp_slo_target_url              { 'https://pint.eauth.va.gov/pkmslogout' }
    idp_sso_target_url              { 'https://pint.eauth.va.gov/isam/sps/saml20idp/saml20/login' }
    name_identifier_format { 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified' }
  end
end
