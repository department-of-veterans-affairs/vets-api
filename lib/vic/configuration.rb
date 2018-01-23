# frozen_string_literal: true

module VIC
  class Configuration < Common::Client::Configuration::REST
    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use :breakers
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
