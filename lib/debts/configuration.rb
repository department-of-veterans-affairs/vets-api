# frozen_string_literal: true

module Debts
  class Configuration < Common::Client::Configuration::REST
    def self.base_request_headers
      super.merge(
        'client_id' => Settings.debts.client_id,
        'client_secret' => Settings.debts.client_secret
      )
    end

    def service_name
      'Debts'
    end

    def base_path
      "#{Settings.debts.url}/api/v1/debtletter/"
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |f|
        f.use     :breakers

        f.request :json
        f.adapter Faraday.default_adapter
        f.response :json
      end
    end
  end
end
