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
              group_name:,
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

        def group_name(vaccine_codes)
          return nil if vaccine_codes.nil?

          log_vaccine_code_processing(vaccine_codes)
          extract_group_name_from_codes(vaccine_codes)
        end

        def log_vaccine_code_processing(vaccine_codes)
          return unless Flipper.enabled?(:mhv_vaccine_lighthouse_name_logging)

          coding_count = vaccine_codes[:coding]&.length || 0
          display_hashes = anonymized_display_hashes(vaccine_codes)
          vaccine_group_lengths = calculate_vaccine_group_lengths(vaccine_codes)

          Rails.logger.info(
            'Immunizations group_name processing',
            coding_count:,
            display_hashes:,
            vaccine_group_lengths:
          )
        end

        def anonymized_display_hashes(vaccine_codes)
          vaccine_codes[:coding]&.map { |v| Digest::SHA256.hexdigest(v[:display].to_s)[0..7] } || []
        end

        def calculate_vaccine_group_lengths(vaccine_codes)
          vaccine_codes[:coding]&.map do |v|
            next unless v[:display]&.start_with?('VACCINE GROUP:')

            # Count characters after "VACCINE GROUP:" including any whitespace (before stripping)
            text_after_group = v[:display].split('VACCINE GROUP').last
            text_after_colon = text_after_group&.sub(/^:/, '')
            text_after_colon&.length || 0
          end&.compact || []
        end

        def extract_group_name_from_codes(vaccine_codes)
          coding = vaccine_codes[:coding]
          return nil if coding.nil?

          # Look for entries that start with the vaccine group prefix
          filtered_codes = coding.select do |v|
            v[:display]&.start_with?('VACCINE GROUP:')
          end

          group_name = if filtered_codes.empty?
                         fallback_group_name(vaccine_codes)
                       else
                         extracted = extract_prefixed_group_name(filtered_codes)
                         # If extraction results in blank/nil, fall back to first non-prefixed display
                         extracted.presence || fallback_group_name(vaccine_codes)
                       end

          group_name.presence
        end

        def fallback_group_name(vaccine_codes)
          # Return coding entry based on system priority (excluding VACCINE GROUP entries)
          coding = vaccine_codes[:coding]
          return nil if coding.nil?

          # Filter out VACCINE GROUP entries
          non_prefixed = coding.reject { |v| v[:display]&.start_with?('VACCINE GROUP:') }

          # Priority 1: system = "http://hl7.org/fhir/sid/cvx"
          cvx_entry = non_prefixed.find { |v| v[:system] == 'http://hl7.org/fhir/sid/cvx' && v[:display].present? }
          return cvx_entry[:display] if cvx_entry

          # Priority 2: system contains "fhir.cerner.com"
          cerner_entry = non_prefixed.find { |v| v[:system]&.include?('fhir.cerner.com') && v[:display].present? }
          return cerner_entry[:display] if cerner_entry

          # Priority 3: system = "http://hl7.org/fhir/sid/ndc"
          ndc_entry = non_prefixed.find { |v| v[:system] == 'http://hl7.org/fhir/sid/ndc' && v[:display].present? }
          return ndc_entry[:display] if ndc_entry

          # Priority 4: First entry without VACCINE GROUP and with a display value
          non_prefixed.find { |v| v[:display].present? }&.dig(:display)
        end

        def extract_prefixed_group_name(filtered_codes)
          # Remove the prefix and clean up whitespace
          group_name = filtered_codes.dig(0, :display)
          group_name&.delete_prefix('VACCINE GROUP:')&.strip
        end

        def date(immunization)
          date = immunization[:occurrence_date_time]
          StatsD.increment('mobile.immunizations.date_missing') if date.blank?

          date.presence
        end

        def cvx_code(vaccine_code)
          return nil if vaccine_code.nil?

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

          series[:series_doses_positive_int] || series[:series_doses_string] || series[:dose_number_string]
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
