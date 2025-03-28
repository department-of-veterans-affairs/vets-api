# frozen_string_literal: true

module DebtsApi
  class V0::FinancialStatusReportConfiguration < Common::Client::Configuration::REST
    def self.base_request_headers
      super.merge(
        'client_id' => Settings.dmc.client_id,
        'client_secret' => Settings.dmc.client_secret
      )
    end

    def service_name
      'FinancialStatusReport'
    end

    def base_path
      Settings.dmc.url
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |f|
        f.use(:breakers, service_name:)
        f.use Faraday::Response::RaiseError
        f.request :json
        f.response :betamocks if Settings.dmc.mock_fsr
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
