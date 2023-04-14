# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/veteran_verification/configuration'
require 'lighthouse/veteran_verification/service_exception'

module VeteranVerification
  class Service < Common::Client::Base
    configuration VeteranVerification::Configuration
    STATSD_KEY_PREFIX = 'api.veteran_verification'

    def get_rated_disabilities(request_body, auth_params = {})
      config.get('disability_rating', request_body, auth_params).body
    rescue Faraday::ClientError => e
      Rails.logger.error(
        VeteranVerification::ServiceException.new(e.response),
        'get_rated_disabilities Lighthouse Error'
      )
    end
  end
end
