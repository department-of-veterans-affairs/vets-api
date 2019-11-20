# frozen_string_literal: true

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
if Settings.vbms.present?
  ENV['CONNECT_VBMS_BASE_URL'] = Settings.vbms.vbms_base_url
  ENV['CONNECT_VBMS_CACERT'] = Settings.vbms.vbms_ca_cert
  ENV['CONNECT_VBMS_CERT'] = Settings.vbms.cert
  ENV['CONNECT_VBMS_CLIENT_KEYFILE'] = Settings.vbms.client_keyfile
  ENV['CONNECT_VBMS_KEYPASS'] = Settings.vbms.keypass
  ENV['CONNECT_VBMS_SAML'] = Settings.vbms.saml
  ENV['CONNECT_VBMS_SERVER_CERT'] = Settings.vbms.server_cert
  ENV['CONNECT_VBMS_SHA256'] = 'true'
  ENV['CONNECT_VBMS_URL'] = "#{Settings.vbms.base_url}/vbmsp2-cms/streaming/eDocumentService-v4"
  ENV['CONNECT_VBMS_ENV_DIR'] = Settings.vbms.environment_directory
end
