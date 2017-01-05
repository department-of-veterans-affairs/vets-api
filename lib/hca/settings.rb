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
    CERT_STORE = (cert_store(CONFIG['ca']) if CONFIG['ca'])
    SSL_CERT = begin
      OpenSSL::X509::Certificate.new(File.read(ENV['ES_CLIENT_CERT_PATH']))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load ES SSL cert: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end
    SSL_KEY = begin
      OpenSSL::PKey::RSA.new(File.read(ENV['ES_CLIENT_KEY_PATH']))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load ES SSL key: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end
  end
end
