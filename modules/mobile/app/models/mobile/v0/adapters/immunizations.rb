# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Immunizations
        def parse(immunizations)
          vaccines = vaccines(immunizations)

          immunizations[:entry].map do |i|
            immunization = i[:resource]
            vaccine_code = immunization[:vaccine_code]
            cvx_code = vaccine_code[:coding].first[:code].to_i
            vaccine = vaccines&.find_by(cvx_code: cvx_code)

            Mobile::V0::Immunization.new(
              id: immunization[:id],
              cvx_code: cvx_code,
              date: immunization[:occurrence_date_time],
              dose_number: dose_number(immunization[:protocol_applied]),
              dose_series: dose_series(immunization[:protocol_applied]),
              group_name: vaccine&.group_name,
              location_id: location_id(immunization.dig(:location, :reference)),
              manufacturer: vaccine&.manufacturer,
              note: note(immunization[:note]),
              reaction: reaction(immunization[:reaction]),
              short_description: vaccine_code[:text]
            )
          end
        end

        private

        def location_id(reference)
          return nil unless reference

          reference.split('/').last
        end

        def dose_number(protocol_applied)
          return nil if protocol_applied.blank?

          series = protocol_applied.first

          series[:dose_number_positive_int] || series[:dose_number_string]
        end

        def dose_series(protocol_applied)
          return nil if protocol_applied.blank?

          series = protocol_applied.first

          series[:series_doses_positive_int] || series[:series_doses_string]
        end

        def note(note)
          return nil if note.blank?

          note.first[:text]
        end

        def reaction(reaction)
          return nil unless reaction

          reaction.map { |r| r[:detail][:display] }.join(',')
        end

        def vaccines(immunizations)
          cvx_codes = immunizations[:entry].collect { |i| i.dig(:resource, :vaccine_code, :coding, 0, :code) }.uniq
          Mobile::V0::Vaccine.where(cvx_code: cvx_codes)
        end
      end
    end
  end
end
