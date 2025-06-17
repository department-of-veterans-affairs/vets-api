# frozen_string_literal: true

require 'lighthouse/veteran_verification/service'
require 'lighthouse/veteran_verification/configuration'

module Mobile
  module V0
    module VeteranVerification
      class Service < ::VeteranVerification::Service
        configuration ::VeteranVerification::Configuration
        STATSD_KEY_PREFIX = 'api.lighthouse.veteran_verification_status.mobile'

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
          StatsD.increment("#{STATSD_KEY_PREFIX}.fail")
          handle_error(e, lighthouse_client_id, endpoint)
        ensure
          StatsD.increment("#{STATSD_KEY_PREFIX}.total")
        end

        private

        def log_not_confirmed(reason)
          ::Rails.logger.info('Mobile Vet Verification Status Success: not confirmed',
                              { not_confirmed: true, not_confirmed_reason: reason })
        end

        def log_confirmed
          ::Rails.logger.info('Mobile Vet Verification Status Success: confirmed', { confirmed: true })
        end
      end
    end
  end
end
