# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/veteran_verification/configuration'
require 'lighthouse/veteran_verification/constants'
require 'lighthouse/service_exception'

module VeteranVerification
  class Service < Common::Client::Base
    configuration VeteranVerification::Configuration
    STATSD_KEY_PREFIX = 'api.veteran_verification'

    # @param [string] icn: the ICN of the target Veteran
    # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
    # @param [string] lighthouse_rsa_key_path: path to the private RSA key used to create the lighthouse_client_id
    # @param [hash] options: options to override aud_claim_url, params, and auth_params
    # @option options [hash] :params body for the request
    # @option options [string] :aud_claim_url option to override the aud_claim_url for LH Veteran Verification APIs
    # @option options [hash] :auth_params a hash to send in auth params to create the access token
    # @option options [string] :host a base host for the Lighthouse API call
    def get_rated_disabilities(icn, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint = 'disability_rating'
      config
        .get(
          "#{endpoint}/#{icn}",
          lighthouse_client_id,
          lighthouse_rsa_key_path,
          options
        )
        .body
    rescue => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    ##
    # Request a veteran's Title 38 status
    #   see https://developer.va.gov/explore/api/veteran-service-history-and-eligibility/docs
    def get_vet_verification_status(icn, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint = 'status'
      response = config.get(
        "#{endpoint}/#{icn}",
        lighthouse_client_id,
        lighthouse_rsa_key_path,
        options
      ).body

      transform_response(response)
    rescue => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.base_api_path}/#{endpoint}"
      )
    end

    def transform_response(response)
      attributes = response['data']['attributes']
      return response if attributes['veteran_status'] != 'not confirmed' || !attributes.include?('not_confirmed_reason')

      if attributes['not_confirmed_reason'] == 'NOT_TITLE_38'
        response['data']['message'] = VeteranVerification::Constants::NOT_ELIGIBLE_MESSAGE
      else
        response['data']['message'] = VeteranVerification::Constants::NOT_FOUND_MESSAGE
      end

      response
    end
  end
end
