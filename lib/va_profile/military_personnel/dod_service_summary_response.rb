# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/dod_service_summary'

module VAProfile
  module MilitaryPersonnel
    class DodServiceSummaryResponse < VAProfile::Response
      attribute :dod_service_summary, VAProfile::Models::DodServiceSummary

      def self.from(raw_response = nil)
        body = raw_response&.body

        dod_service_summary = get_dod_service_summary(body)

        new(
          raw_response&.status,
          dod_service_summary:
        )
      end

      def self.get_dod_service_summary(body)
        return nil unless body

        summary_data = body&.dig(
          'profile',
          'military_person',
          'military_summary',
          'customer_type',
          'dod_service_summary'
        )

        return nil unless summary_data

        VAProfile::Models::DodServiceSummary.new(
          dod_service_summary_code: summary_data['dod_service_summary_code'],
          calculation_model_version: summary_data['calculation_model_version'],
          effective_start_date: summary_data['effective_start_date']
        )
      end
    end
  end
end
