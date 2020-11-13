# frozen_string_literal: true

module DMC
  class BaseConfiguration < Common::Client::Configuration::REST
    def self.base_request_headers
      super.merge(
        'client_id' => Settings.dmc.client_id,
        'client_secret' => Settings.dmc.client_secret
      )
    end

    def base_path
      "#{Settings.dmc.url}/api/v1/digital-services/"
    end

    def mock_enabled?
      Settings.dmc.send("mock_#{service_name.downcase}")
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |f|
        f.use :breakers
        f.use Faraday::Response::RaiseError
        f.request :json
        f.response :betamocks if mock_enabled?
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
