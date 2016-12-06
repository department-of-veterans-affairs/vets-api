hca_config_file = Rails.application.config_for(:health_care_application).freeze

HEALTH_CARE_APPLICATION_CONFIG = {
  wsdl: Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl'),
  endpoint: hca_config_file['endpoint'],
  ca: hca_config_file['ca'].map { |path| Rails.root.join('config', 'health_care_application','certs', path)},
  cert_path: ENV['HEALTH_CARE_APPLICATION_CERTIFICATE_FILE'],
  key_path: ENV['HEALTH_CARE_APPLICATION_KEY_FILE']
}
