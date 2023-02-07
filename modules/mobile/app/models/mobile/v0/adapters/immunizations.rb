# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Immunizations
        def parse(immunizations)
          return [] unless immunizations[:entry]

          vaccine_map = immunizations[:entry].map do |i|
            immunization = i[:resource]
            group_name = group_name(immunization[:vaccine_code])

            Mobile::V0::Immunization.new(
              id: immunization[:id],
              cvx_code: cvx_code(immunization[:vaccine_code]),
              date: date(immunization),
              dose_number: dose_number(immunization[:protocol_applied]),
              dose_series: dose_series(immunization[:protocol_applied]),
              group_name: group_name,
              location_id: location_id(immunization.dig(:location, :reference)),
              manufacturer: manufacturer(immunization, group_name),
              note: note(immunization[:note]),
              reaction: reaction(immunization[:reaction]),
              short_description: immunization[:vaccine_code][:text]
            )
          end
          vaccine_map = vaccine_map.uniq { |immunization| [immunization[:date], immunization[:short_description]] }
          sort_by_date_and_group_name(vaccine_map)
        end

        private

        def sort_by_date_and_group_name(vaccine_map)
          vaccine_map.sort_by do |immunization|
            date_sort_key1 = immunization[:date] ? 0 : 1 # used to keep nil dates at end of list
            date_sort_key2 = immunization[:date] ? -immunization[:date].to_i : nil
            group_sort_key1 = immunization[:group_name] ? 0 : 1 # used to keep nil group_names at the end of the list
            group_sort_key2 = immunization[:group_name]

            [[date_sort_key1, date_sort_key2], [group_sort_key1, group_sort_key2]]
          end
        end

        def manufacturer(immunization, group_name)
          if group_name == 'COVID-19'
            manufacturer = immunization.dig(:manufacturer, :display)
            StatsD.increment('mobile.immunizations.covid_manufacturer_missing') if manufacturer.blank?
          end

          manufacturer.presence
        end

        def group_name(vaccine_code)
          group_name = vaccine_code.dig(:coding, 1, :display)
          group_name&.slice!('VACCINE GROUP: ')
          group_name.presence
        end

        def date(immunization)
          date = immunization[:occurrence_date_time]
          StatsD.increment('mobile.immunizations.date_missing') if date.blank?

          date.presence
        end

        def cvx_code(vaccine_code)
          code = vaccine_code.dig(:coding, 0, :code)
          StatsD.increment('mobile.immunizations.cvx_code_missing') if code.blank?

          code.presence&.to_i
        end

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
      end
    end
  end
end
