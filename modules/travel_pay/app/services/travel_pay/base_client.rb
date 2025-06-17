# frozen_string_literal: true

require 'securerandom'

module TravelPay
  class BaseClient
    def claim_headers
      if Settings.vsp_environment == 'production'
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key-E' => Settings.travel_pay.subscription_key_e,
          'Ocp-Apim-Subscription-Key-S' => Settings.travel_pay.subscription_key_s
        }
      else
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key' => Settings.travel_pay.subscription_key
        }
      end
    end

    ##
    # Create a Faraday connection object
    # @return [Faraday::Connection]
    #
    def connection(server_url:)
      service_name = Settings.travel_pay.service_name

      Faraday.new(url: server_url) do |conn|
        conn.use(:breakers, service_name:)
        conn.response :raise_custom_error, error_prefix: service_name, include_request: true
        conn.response :betamocks if mock_enabled?
        conn.response :json
        conn.request :json

        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # Syntactic sugar for determining if the client should use
    # fake api responses or actually connect to the BTSSS API
    def mock_enabled?
      Settings.travel_pay.mock
    end

    ##
    # Helper function to measure xTIC latency
    # when calling the external Travel Pay API
    def log_to_statsd(service, tag_value)
      start_time = Time.current
      result = yield
      elapsed_time = Time.current - start_time
      StatsD.measure("travel_pay.#{service}.response_time", elapsed_time, tags: ["travel_pay:#{tag_value}"])
      result
    end
  end
end
