# frozen_string_literal: true
FactoryGirl.define do
  factory :rubysaml_settings, class: 'OneLogin::RubySaml::Settings' do
    certificate                     SAML_CONFIG['certificate']
    private_key                     SAML_CONFIG['key']
    issuer                          SAML_CONFIG['issuer']
    assertion_consumer_service_url  SAML_CONFIG['callback_url']
    authn_context                   'authentication'
    idp_cert                        File.read("#{::Rails.root}/spec/fixtures/files/saml_response.xml")
    idp_cert_fingerprint            '74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32'
    idp_entity_id                   'api.idmelabs.com'
    idp_slo_target_url              'https://api.idmelabs.com/saml/SingleLogoutService'
    idp_sso_target_url              'https://api.idmelabs.com/saml/SingleSignOnService'
    name_identifier_format          'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
  end
end
