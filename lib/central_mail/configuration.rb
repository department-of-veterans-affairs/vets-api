# frozen_string_literal: true

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
        faraday.request :multipart
        faraday.request :url_encoded

        faraday.use :breakers
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
