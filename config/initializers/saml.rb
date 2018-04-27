# frozen_string_literal: true

def new_saml_cert_exists?
  !Settings.saml.cert_new_path.nil? && File.file?(File.expand_path(Settings.saml.cert_new_path))
end

Settings.saml.certificate = File.read(File.expand_path(Settings.saml.cert_path))
Settings.saml.key = File.read(File.expand_path(Settings.saml.key_path))
Settings.saml.certificate_new = new_saml_cert_exists? ? File.read(File.expand_path(Settings.saml.cert_new_path)) : nil
