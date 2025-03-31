# frozen_string_literal: true

require 'faraday/multipart'

module CentralMail
  class Configuration < Common::Client::Configuration::REST
    def base_path
      "https://#{Settings.central_mail.upload.host}/VADocument"
    end

    def service_name
      'CentralMail'
    end

    def connection
      Faraday.new(base_path) do |faraday|
        faraday.use(:breakers, service_name:)

        faraday.request :multipart
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
