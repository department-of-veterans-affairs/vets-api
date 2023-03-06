# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service_exception'

module BenefitsClaims
  class Service < Common::Client::Base
    configuration BenefitsClaims::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_claims'

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?
    end

    def get_claims
      config.get("#{@icn}/claims").body
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_claim(id)
      config.get("#{@icn}/claims/#{id}").body
    rescue Faraday::ClientError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end
  end
end
