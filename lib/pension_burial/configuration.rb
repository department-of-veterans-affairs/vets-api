# frozen_string_literal: true

module PensionBurial
  class Configuration < Common::Client::Configuration::REST
    def base_path
      "https://#{Settings.pension_burial.upload.host}/VADocument"
    end

    def service_name
      'PensionBurial'
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
