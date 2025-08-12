# frozen_string_literal: true

module TravelClaim
  # Client for Travel Pay specific auth needs
  class TravelPayClient
    extend Forwardable
    include SentryLogging

    GRANT_TYPE = 'client_credentials'

    attr_reader :settings, :check_in

    def_delegators :settings,
                   :auth_url,
                   :tenant_id,
                   :travel_pay_client_id,
                   :travel_pay_client_secret,
                   :scope,
                   :service_name,
                   :subscription_key,
                   :e_subscription_key,
                   :s_subscription_key

    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @settings = Settings.check_in.travel_reimbursement_api_v2
      @check_in = opts[:check_in]
    end

    # Obtain a VEIS OAuth token using Travel Pay client credentials
    #
    # @return [Faraday::Response]
    def token
      connection(server_url: auth_url).post("/#{tenant_id}/oauth2/v2.0/token") do |req|
        req.headers = default_headers
        req.body = URI.encode_www_form(auth_params)
      end
    rescue => e
      Rails.logger.error(message: 'TravelPayClient token error', uuid: check_in&.uuid,
                         external_service: service_name, error: e.original_body)
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in&.uuid },
                            { external_service: service_name, team: 'check-in' })
      raise e
    end

    # Exchange a VEIS access token for a BTSSS system access token (Travel Pay API v4)
    #
    # @param veis_access_token [String] The OAuth access token obtained from VEIS
    # @return [Faraday::Response]
    def system_access_token(veis_access_token:)
      connection(server_url: travel_pay_base_url).post('/api/v4/auth/system-access-token') do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Correlation-ID'] = SecureRandom.uuid
        req.headers['OCP-APIM-Subscription-Key'] = subscription_key
        req.headers['OCP-APIM-Subscription-Key-E'] = e_subscription_key
        req.headers['OCP-APIM-Subscription-Key-S'] = s_subscription_key
        req.headers['Authorization'] = "Bearer #{veis_access_token}"
        req.body = { secret: travel_pay_client_secret }.to_json
      end
    rescue => e
      Rails.logger.error(message: 'TravelPayClient system_access_token error', uuid: check_in&.uuid,
                         external_service: service_name, error: e.original_body)
      log_message_to_sentry(e.original_body, :error,
                            { uuid: check_in&.uuid },
                            { external_service: service_name, team: 'check-in' })
      raise e
    end

    private

    def connection(server_url:)
      Faraday.new(url: server_url) do |conn|
        conn.use(:breakers, service_name:)
        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :betamocks if mock_enabled?
        conn.adapter Faraday.default_adapter
      end
    end

    def default_headers
      { 'Content-Type' => 'application/x-www-form-urlencoded' }
    end

    def auth_params
      {
        client_id: travel_pay_client_id,
        client_secret: travel_pay_client_secret,
        scope:,
        grant_type: GRANT_TYPE
      }
    end

    def travel_pay_base_url
      settings.claims_url_v2
    end

    def mock_enabled?
      settings.mock || Flipper.enabled?('check_in_experience_mock_enabled')
    end
  end
end
