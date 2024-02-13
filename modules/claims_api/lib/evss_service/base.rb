# frozen_string_literal: true

require 'claims_api/v2/benefits_documents/service'
require 'claims_api/claim_logger'
require 'common/client/errors'

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
        @use_mock = Settings.evss.mock_claims || false
      end

      def submit(claim, data)
        @auth_headers = claim.auth_headers

        begin
          resp = client.post('submit', data)&.body&.deep_symbolize_keys
          log_outcome_for_claims_api('submit', 'success', resp, claim)

          resp # return is for v1 Sidekiq worker
        rescue => e
          error_handler(e, claim)
        end
      end

      def validate(claim, data)
        @auth_headers = claim.auth_headers

        begin
          resp = client.post('validate', data)&.body&.deep_symbolize_keys
          log_outcome_for_claims_api('validate', 'success', resp, claim)

          resp
        rescue => e
          detail = e.respond_to?(:original_body) ? e.original_body : e
          log_outcome_for_claims_api('validate', 'error', detail, claim)

          formatted_err = error_handler(e, claim) # for v1 controller reporting
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
                    ssl: { verify: Settings.evss&.dvp&.ssl != false },
                    headers:) do |f|
          f.request :json
          f.response :betamocks if @use_mock
          f.response :raise_error
          f.response :json, parser_options: { symbolize_names: true }
          f.adapter Faraday.default_adapter
        end
      end

      def headers
        return @auth_headers if @use_mock # no sense in getting a token if the target request is mocked

        client_key = Settings.claims_api.evss_container&.client_key || ENV.fetch('EVSS_CLIENT_KEY', '')
        raise StandardError, 'EVSS client_key missing' if client_key.blank?

        @auth_headers.merge!({
                               Authorization: "Bearer #{access_token}",
                               'client-key': client_key,
                               'content-type': 'application/json; charset=UTF-8'
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

      def error_handler(error, claim)
        log_info = {}
        handle_faraday_failure(error, log_info, claim)
        handle_bad_request(error, log_info, claim)
        handle_parsing_error(error, log_info, claim)
        handle_client_errors(error, log_info, claim)
        raise error
      end

      def handle_faraday_failure(error, log_info, claim)
        if error.is_a?(Faraday::ConnectionFailed)
          log_info['class'] = error.class if error.respond_to?(:class)
          log_info['status'] = error.response_status if error.respond_to?(:response_status)
          log_info['message'] = error.detailed_message if error.respond_to?(:detailed_message)
          log_outcome_for_claims_api('submit', 'error', log_info, claim)
          raise ::Common::Exceptions::ServiceUnavailable
        end
      end

      def handle_client_errors(error, log_info, claim)
        status = error.status if error.respond_to?(:status)
        if ::Common::Client::Errors::ClientError
          log_info['class'] = error.class if error.respond_to?(:class)
          log_info['status'] = status
          log_info['message'] = error.message.presence || error.detailed_message
          log_outcome_for_claims_api('submit', 'error', log_info, claim)

          raise ::Common::Exceptions::Forbidden if status == 403
          raise ::Common::Exceptions::BadRequest if [400, nil].include?(status)
          raise ::Common::Exceptions::Authorization if status == 401
          raise ::Common::Exceptions::ServiceError if status == 503
        end
      end

      def handle_parsing_error(error, log_info, claim)
        if error.is_a?(Faraday::ParsingError)
          log_info['class'] = error.class if error.respond_to?(:class)
          status = error.response_status if error.respond_to?(:response_status)
          log_info['status'] = status
          log_info['message'] = error.detailed_message if error.respond_to?(:detailed_message)
          log_outcome_for_claims_api('submit', 'error', log_info, claim)
          raise ::Common::Exceptions::BadRequest if [400, nil].include?(status)
          raise ::Common::Exceptions::InternalServerError if status == 500
        end
      end

      def handle_bad_request(error, log_info, claim)
        status = error.status_code if error.respond_to?(:status_code)
        if error.is_a?(::Common::Exceptions::BadRequest) && status != 403
          log_info['message'] = error.message.presence || error.detailed_message
          log_info['class'] = error.class if error.respond_to?(:class)
          log_info['status'] = status
          log_outcome_for_claims_api('submit', 'error', log_info, claim)

          raise ::Common::Exceptions::ServiceUnavailable
        end
      end
    end
  end
end
