# frozen_string_literal: true
module PensionBurial
  class Configuration < Common::Client::Configuration::REST
    def connection
      Faraday.new(base_path) do |faraday|
        faraday.use :breakers
        faraday.response :json
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
