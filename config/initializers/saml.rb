# frozen_string_literal: true

# rubocop:disable Layout/LineLength

def saml_ssoe_cert_exists?
  !IdentitySettings.saml_ssoe.cert_path.nil? && File.file?(File.expand_path(IdentitySettings.saml_ssoe.cert_path))
end

def saml_ssoe_key_exists?
  !IdentitySettings.saml_ssoe.key_path.nil? && File.file?(File.expand_path(IdentitySettings.saml_ssoe.key_path))
end

def new_saml_ssoe_cert_exists?
  !IdentitySettings.saml_ssoe.cert_new_path.nil? && File.file?(File.expand_path(IdentitySettings.saml_ssoe.cert_new_path))
end

IdentitySettings.saml_ssoe.certificate = saml_ssoe_cert_exists? ? File.read(File.expand_path(IdentitySettings.saml_ssoe.cert_path)) : nil
IdentitySettings.saml_ssoe.key = saml_ssoe_key_exists? ? File.read(File.expand_path(IdentitySettings.saml_ssoe.key_path)) : nil
IdentitySettings.saml_ssoe.certificate_new = new_saml_ssoe_cert_exists? ? File.read(File.expand_path(IdentitySettings.saml_ssoe.cert_new_path)) : nil
# rubocop:enable Layout/LineLength
