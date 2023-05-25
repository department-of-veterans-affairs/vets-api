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
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_claim(id, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      config.get("#{@icn}/claims/#{id}", lighthouse_client_id, lighthouse_rsa_key_path, options).body
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

    private

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
