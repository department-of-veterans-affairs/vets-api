# frozen_string_literal: true

# Concern for adding deprecation warnings to EVSS endpoints

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
            days_until_sunset: days_until_sunset
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
        headers = response.headers
        headers['Deprecation'] = "date=\"#{EVSS_SUNSET_DATE}\""
        headers['Sunset'] = EVSS_SUNSET_DATE
        headers['Link'] = '</v0/benefits_claims>; rel="alternate"; title="Replacement endpoint using Lighthouse"'
        headers['Warning'] = "299 - \"#{DEPRECATION_MESSAGE}\""
      end

      def days_until_sunset
        sunset = Date.parse(EVSS_SUNSET_DATE)
        (sunset - Time.zone.today).to_i
      end
    end
  end
end
