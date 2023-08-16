# frozen_string_literal: true

module ClaimsApi
  ##
  # Class to interact with the EVSS container
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  module EVSSService
    class Base
      require_relative 'token'

      def initialize(request = nil)
        @request = request
        @auth_headers = {}
      end

      def submit(claim, data)
        @auth_headers = claim.auth_headers

        begin
          client.post('submit', data).body
        rescue => e
          detail = e.respond_to?(:original_body) ? e.original_body : e
          ClaimsApi::Logger.log('526',
                                detail: "EVSS DOCKER CONTAINER submit error: #{detail}", claim_id: claim.id)
        end
      end

      private

      def client
        base_name = Settings.evss&.dvp&.url
        service_name = Settings.evss&.service_name
        raise StandardError, 'DVP URL missing' if base_name.blank?

        Faraday.new("#{base_name}/#{service_name}/rest/form526/v2",
                    # Disable SSL for (localhost) testing
                    ssl: { verify: Settings.dvp&.ssl != false },
                    headers:) do |f|
          f.request :json
          f.response :raise_error
          f.response :json, parser_options: { symbolize_names: true }
          f.adapter Faraday.default_adapter
        end
      end

      def headers
        client_key = Settings.claims_api.evss_container&.client_key || ENV.fetch('EVSS_CLIENT_KEY', '')
        raise StandardError, 'EVSS client_key missing' if client_key.blank?

        @auth_headers.merge!({
                               Authorization: "Bearer #{access_token}",
                               'client-key': client_key
                             })
        @auth_headers.transform_keys(&:to_s)
      end

      def access_token
        @access_token ||= ClaimsApi::EVSSService::Token.new(@request).get_token
      end
    end
  end
end
