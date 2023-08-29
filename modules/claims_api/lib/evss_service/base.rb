# frozen_string_literal: true

require 'claims_api/v2/benefits_documents/service'

module ClaimsApi
  ##
  # Class to interact with the EVSS container
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  module EVSSService
    class Base
      def initialize(request = nil)
        @request = request
        @auth_headers = {}
      end

      def submit(claim, data)
        @auth_headers = claim.auth_headers

        begin
          resp = client.post('submit', data).body
          ClaimsApi::Logger.log('526',
                                detail: 'EVSS DOCKER CONTAINER submit success', evss_response: resp)
          resp # return is for v1 Sidekiq worker
        rescue => e
          detail = e.respond_to?(:original_body) ? e.original_body : e
          ClaimsApi::Logger.log('526',
                                detail: "EVSS DOCKER CONTAINER submit error: #{detail}", claim_id: claim&.id)
          e # return is for v1 Sidekiq worker
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
        @auth_token ||= ClaimsApi::V2::BenefitsDocuments::Service.new.get_auth_token
      end
    end
  end
end
