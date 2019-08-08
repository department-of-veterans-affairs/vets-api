# frozen_string_literal: true

def new_saml_cert_exists?
  !Settings.saml.cert_new_path.nil? && File.file?(File.expand_path(Settings.saml.cert_new_path))
end

Settings.saml.certificate = File.read(File.expand_path(Settings.saml.cert_path))
Settings.saml.key = File.read(File.expand_path(Settings.saml.key_path))
Settings.saml.certificate_new = new_saml_cert_exists? ? File.read(File.expand_path(Settings.saml.cert_new_path)) : nil

def new_saml_ssoe_cert_exists?
  !Settings.saml_ssoe.cert_new_path.nil? && File.file?(File.expand_path(Settings.saml_ssoe.cert_new_path))
end

Settings.saml_ssoe.certificate = File.read(File.expand_path(Settings.saml_ssoe.cert_path))
Settings.saml_ssoe.key = File.read(File.expand_path(Settings.saml_ssoe.key_path))
Settings.saml_ssoe.certificate_new = new_saml_ssoe_cert_exists? ? File.read(File.expand_path(Settings.saml_ssoe.cert_new_path)) : nil
