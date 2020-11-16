# frozen_string_literal: true

# rubocop:disable Layout/LineLength

def new_saml_cert_exists?
  !Settings.saml.cert_new_path.nil? && File.file?(File.expand_path(Settings.saml.cert_new_path))
end

Settings.saml.certificate = File.read(File.expand_path(Settings.saml.cert_path))
Settings.saml.key = File.read(File.expand_path(Settings.saml.key_path))
Settings.saml.certificate_new = new_saml_cert_exists? ? File.read(File.expand_path(Settings.saml.cert_new_path)) : nil

def saml_ssoe_cert_exists?
  !Settings.saml_ssoe.cert_path.nil? && File.file?(File.expand_path(Settings.saml_ssoe.cert_path))
end

def saml_ssoe_key_exists?
  !Settings.saml_ssoe.key_path.nil? && File.file?(File.expand_path(Settings.saml_ssoe.key_path))
end

def new_saml_ssoe_cert_exists?
  !Settings.saml_ssoe.cert_new_path.nil? && File.file?(File.expand_path(Settings.saml_ssoe.cert_new_path))
end

Settings.saml_ssoe.certificate = saml_ssoe_cert_exists? ? File.read(File.expand_path(Settings.saml_ssoe.cert_path)) : nil
Settings.saml_ssoe.key = saml_ssoe_key_exists? ? File.read(File.expand_path(Settings.saml_ssoe.key_path)) : nil
Settings.saml_ssoe.certificate_new = new_saml_ssoe_cert_exists? ? File.read(File.expand_path(Settings.saml_ssoe.cert_new_path)) : nil
# rubocop:enable Layout/LineLength
