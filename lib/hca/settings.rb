# frozen_string_literal: true
module HCA
  module Settings
    CONFIG = Rails.application.config_for(:health_care_application).freeze

    def self.cert_store(paths)
      store = OpenSSL::X509::Store.new
      Array(paths).each do |path|
        store.add_file(Rails.root.join('config', 'health_care_application', 'certs', path).to_s)
      end
      store
    end

    HEALTH_CHECK_ID = 377_609_264
    WSDL = Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl')
    ENDPOINT = CONFIG['endpoint']
    CERT_STORE = cert_store(CONFIG['ca'])
    SSL_CERT = ENV['ES_CLIENT_CERT_PATH']
    SSL_KEY = ENV['ES_CLIENT_KEY_PATH']
  end
end
