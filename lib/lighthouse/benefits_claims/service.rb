# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service_exception'
require 'lighthouse/service_exception'

module BenefitsClaims
  class Service < Common::Client::Base
    configuration BenefitsClaims::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_claims'

    FILTERED_STATUSES = %w[CANCELED ERRORED PENDING].freeze

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?

      super()
    end

    def get_claims(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      claims = config.get("#{@icn}/claims", lighthouse_client_id, lighthouse_rsa_key_path, options).body
      claims['data'] = filter_by_status(claims['data'])
      claims
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_claim(id, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      config.get("#{@icn}/claims/#{id}", lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def submit5103(id, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      config.post("#{@icn}/claims/#{id}/5103", {}, lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_intent_to_file(type, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint = 'benefits_claims/intent_to_file'
      path = "#{@icn}/intent-to-file/#{type}"
      config.get(path, lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::ClientError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    # For type "survivor", the request must include claimantSsn and be made by a valid Veteran Representative.
    # If the Representative is not a Veteran or a VA employee, this method is currently not available to them,
    # and they should use the Benefits Intake API as an alternative.
    def create_intent_to_file(type, claimant_ssn, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil,
                              options = {})
      if claimant_ssn.blank? && type == 'survivor'
        raise ArgumentError, 'BenefitsClaims::Service: No SSN provided for survivor type create request.'
      end

      endpoint = 'benefits_claims/intent_to_file'
      path = "#{@icn}/intent-to-file"
      config.post(
        path,
        {
          data: {
            type: 'intent_to_file',
            attributes: {
              type:,
              claimantSsn: claimant_ssn
            }
          }
        },
        lighthouse_client_id, lighthouse_rsa_key_path, options
      ).body
    rescue Faraday::ClientError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    # submit form526 to Lighthouse API endpoint: /services/claims/v2/veterans/{veteranId}/526
    # @param [hash || Requests::Form526] body: a hash representing the form526
    # attributes in the Lighthouse request schema
    # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
    # @param [string] lighthouse_rsa_key_path: absolute path to the rsa key file
    # @param [hash] options: options to override aud_claim_url, params, and auth_params
    # @option options [hash] :body_only only return the body from the request
    # @option options [string] :aud_claim_url option to override the aud_claim_url for LH Veteran Verification APIs
    # @option options [hash] :auth_params a hash to send in auth params to create the access token
    def submit526(body, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint = 'benefits_claims/form/526'
      path = "#{@icn}/526"

      # if we're coming straight from the transformation service without
      # making this a jsonapi request body first ({data: {type:, attributes}}),
      # this will put it in the correct format for transmission
      if body['attributes'].blank?
        body = {
          data: {
            type: 'form/526',
            attributes: body
          }
        }.as_json.deep_transform_keys { |k| k.camelize(:lower) }
      end

      response = config.post(
        path,
        body,
        lighthouse_client_id, lighthouse_rsa_key_path, options
      )

      submit_response(response, options[:body_only])
    rescue Faraday::ClientError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    private

    def submit_response(response, body_only)
      if body_only
        # return only the response body
        response.body
      else
        # return the whole response
        response
      end
    end

    def filter_by_status(items)
      items.reject { |item| FILTERED_STATUSES.include?(item.dig('attributes', 'status')) }
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.base_api_path}/#{endpoint}"
      )
    end
  end
end
