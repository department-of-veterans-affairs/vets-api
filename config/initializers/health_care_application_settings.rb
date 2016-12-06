hca_config_file = Rails.application.config_for(:health_care_application).freeze

def cert_store(paths)
  store = OpenSSL::X509::Store.new
  paths.each { |path|
    store.add_file(Rails.root.join('config', 'health_care_application','certs', path).to_s)
  }
  store
end

HEALTH_CARE_APPLICATION_CONFIG = {
  wsdl: Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl'),
  endpoint: hca_config_file['endpoint'],
  cert_store: cert_store(hca_config_file['ca']),
  cert_path: ENV['HEALTH_CARE_APPLICATION_CERTIFICATE_FILE'],
  key_path: ENV['HEALTH_CARE_APPLICATION_KEY_FILE']
}
