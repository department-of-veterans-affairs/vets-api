# frozen_string_literal: true

# Concern for adding deprecation warnings to EVSS endpoints
#
# EVSS is being sunset on January 28, 2026. This concern adds deprecation
# headers, metadata, and logging to all EVSS controller responses.
#

module V0
  module Concerns
    module EVSSDeprecation
      extend ActiveSupport::Concern

      EVSS_SUNSET_DATE = '2026-01-28'
      DEPRECATION_MESSAGE = 'The EVSS Claims API is deprecated and will be shut down on January 28, 2026. ' \
                            'Please migrate to the /v0/benefits_claims endpoint which uses Lighthouse.'

      included do
        before_action :log_evss_deprecation_warning
        after_action :add_deprecation_headers
      end

      private

      def log_evss_deprecation_warning
        Rails.logger.warn(
          'EVSS endpoint accessed - service will be deprecated',
          {
            message_type: 'evss.deprecation_warning',
            endpoint: request.path,
            user_uuid: current_user&.uuid,
            sunset_date: EVSS_SUNSET_DATE,
            days_until_sunset:
          }
        )

        StatsD.increment(
          'api.evss.deprecation_warning',
          tags: [
            "endpoint:#{controller_name}",
            "action:#{action_name}",
            'service:evss'
          ]
        )
      end

      def add_deprecation_headers
        response.headers['Deprecation'] = "date=\"#{EVSS_SUNSET_DATE}\""
        response.headers['Sunset'] = EVSS_SUNSET_DATE
        response.headers['Link'] =
          '</v0/benefits_claims>; rel="alternate"; title="Replacement endpoint using Lighthouse"'
        response.headers['Warning'] = "299 - \"#{DEPRECATION_MESSAGE}\""
      end

      def add_deprecation_metadata(response_hash)
        meta = response_hash['meta'] || {}
        meta['deprecation'] = {
          'deprecated' => true,
          'sunset_date' => EVSS_SUNSET_DATE,
          'days_remaining' => days_until_sunset,
          'message' => DEPRECATION_MESSAGE,
          'replacement_endpoint' => '/v0/benefits_claims'
        }
        response_hash['meta'] = meta
        response_hash
      end

      def days_until_sunset
        sunset = Date.parse(EVSS_SUNSET_DATE)
        (sunset - Time.zone.today).to_i
      end
    end
  end
end
