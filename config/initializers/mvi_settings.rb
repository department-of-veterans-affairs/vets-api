# frozen_string_literal: true
module MVI
  module Settings
    URL = ENV['MVI_URL']
    SSL_CERT = begin
      OpenSSL::X509::Certificate.new(File.read(ENV['MVI_CLIENT_CERT_PATH']))
    rescue => e
      Rails.logger.warn "Could not load MVI SSL cert: #{e.message}"
      raise e if Rails.env.production?
      nil
    end
    SSL_KEY = begin
      OpenSSL::PKey::RSA.new(File.read(ENV['MVI_CLIENT_KEY_PATH']))
    rescue => e
      Rails.logger.warn "Could not load MVI SSL key: #{e.message}"
      raise e if Rails.env.production?
      nil
    end
  end
end
