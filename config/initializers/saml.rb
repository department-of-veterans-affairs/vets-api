# frozen_string_literal: true
Settings.saml.certificate = File.read(File.expand_path(Settings.saml.cert_path))
Settings.saml.key = File.read(File.expand_path(Settings.saml.key_path))
Settings.saml.certificate_new = File.read(File.expand_path(Settings.saml.cert_new_path))
