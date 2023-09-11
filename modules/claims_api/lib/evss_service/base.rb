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
          resp = client.post('submit', data)&.body
          log_outcome_for_claims_api('submit', 'success', resp, claim)

          resp # return is for v1 Sidekiq worker
        rescue => e
          detail = e.respond_to?(:original_body) ? e.original_body : e
          log_outcome_for_claims_api('submit', 'error', detail, claim)

          e # return is for v1 Sidekiq worker
        end
      end

      def validate(claim, data)
        @auth_headers = claim.auth_headers
        @auth_headers['va_eauth_birlsfilenumber'] = @auth_headers['va_eauth_pnid']

        begin
          resp = client.post('validate', data)&.body
          log_outcome_for_claims_api('validate', 'success', resp, claim)

          resp
        rescue => e
          detail = e.respond_to?(:original_body) ? e.original_body : e
          log_outcome_for_claims_api('validate', 'error', detail, claim)

          formatted_err = handle_error(e) # for v1 controller reporting
          raise formatted_err
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

      def handle_error(e)
        # if orignal_body we have a Docker Container error
        if e.respond_to?(:original_body)
          errors = format_docker_container_error_for_v1(e.original_body[:messages])
          e.original_body[:messages] = errors
        end
        e
      end

      # v1/disability_compenstaion_controller expects different values then the docker container provides
      def format_docker_container_error_for_v1(errors)
        errors.each do |err|
          # need to add a :detail key v1 looks for in it's error reporting, get :text key from docker container
          err.merge!(detail: err[:text]).stringify_keys!
        end
      end

      def log_outcome_for_claims_api(action, status, response, claim)
        ClaimsApi::Logger.log('526_docker_container',
                              detail: "EVSS DOCKER CONTAINER #{action} #{status}: #{response}", claim: claim&.id)
      end
    end
  end
end
