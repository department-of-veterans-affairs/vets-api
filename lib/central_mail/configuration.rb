# frozen_string_literal: true

module CentralMail
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = 120

    def base_path
      "https://#{Settings.central_mail.upload.host}/VADocument"
    end

    def service_name
      'CentralMail'
    end

    def connection
      Faraday.new(base_path, request: request_options) do |faraday|
        faraday.use     :breakers

        faraday.request :multipart
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
