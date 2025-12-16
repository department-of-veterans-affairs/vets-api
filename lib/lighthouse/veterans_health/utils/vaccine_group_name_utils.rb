# frozen_string_literal: true

require 'uri'
require 'digest'

module Lighthouse
  module VeteransHealth
    module Utils
      # Utility class for extracting vaccine group names from FHIR vaccine code data
      # Handles both symbol-keyed and string-keyed hashes for maximum compatibility
      class VaccineGroupNameUtils
        class << self
          # Extracts the vaccine group name from vaccine code data
          #
          # @param vaccine_code [Hash] the vaccine code hash (with symbol or string keys)
          # @return [String, nil] the extracted group name or nil
          def extract_group_name(vaccine_code)
            return nil if vaccine_code.nil?

            coding = extract_coding(vaccine_code)

            # Log processing even if coding is nil (for monitoring)
            log_vaccine_code_processing(coding) if Flipper.enabled?(:mhv_vaccine_lighthouse_name_logging)

            return nil if coding.nil?

            extract_group_name_from_codes(coding)
          end

          private

          def extract_coding(vaccine_code)
            vaccine_code[:coding] || vaccine_code['coding']
          end

          def log_vaccine_code_processing(coding)
            coding_count = coding&.length || 0
            display_hashes = anonymized_display_hashes(coding)
            vaccine_group_lengths = calculate_vaccine_group_lengths(coding)

            Rails.logger.info(
              'Immunizations group_name processing',
              coding_count:,
              display_hashes:,
              vaccine_group_lengths:
            )
          end

          def anonymized_display_hashes(coding)
            return [] if coding.nil?

            coding.map do |v|
              display = v[:display] || v['display']
              display ? Digest::SHA256.hexdigest(display.to_s)[0..7] : nil
            end
          end

          def calculate_vaccine_group_lengths(coding)
            return [] if coding.nil?

            coding.filter_map do |v|
              display = v[:display] || v['display']
              next unless display&.start_with?('VACCINE GROUP:')

              # Count characters after "VACCINE GROUP:" including any whitespace (before stripping)
              text_after_group = display.split('VACCINE GROUP').last
              text_after_colon = text_after_group&.sub(/^:/, '')
              text_after_colon&.length || 0
            end
          end

          def extract_group_name_from_codes(coding)
            # Look for entries that start with the vaccine group prefix
            filtered_codes = coding.select do |v|
              display = v[:display] || v['display']
              display&.start_with?('VACCINE GROUP:')
            end

            group_name = if filtered_codes.empty?
                           fallback_group_name(coding)
                         else
                           extracted = extract_prefixed_group_name(filtered_codes)
                           # If extraction results in blank/nil, fall back to first non-prefixed display
                           extracted.presence || fallback_group_name(coding)
                         end

            group_name.presence
          end

          def fallback_group_name(coding)
            # Return coding entry based on system priority (excluding VACCINE GROUP entries)
            return nil if coding.nil?

            non_prefixed = filter_vaccine_group_entries(coding)

            find_cvx_entry(non_prefixed) ||
              find_cerner_entry(non_prefixed) ||
              find_ndc_entry(non_prefixed) ||
              find_first_display_entry(non_prefixed)
          end

          def filter_vaccine_group_entries(coding)
            coding.reject do |v|
              display = v[:display] || v['display']
              display&.start_with?('VACCINE GROUP:')
            end
          end

          def find_cvx_entry(entries)
            entry = entries.find do |v|
              system = v[:system] || v['system']
              display = v[:display] || v['display']
              system == 'http://hl7.org/fhir/sid/cvx' && display.present?
            end
            entry ? (entry[:display] || entry['display']) : nil
          end

          def find_cerner_entry(entries)
            entry = entries.find do |v|
              display = v[:display] || v['display']
              system = v[:system] || v['system']
              next false unless display.present? && system.present?

              cerner_system?(system)
            end
            entry ? (entry[:display] || entry['display']) : nil
          end

          def cerner_system?(system)
            uri = URI.parse(system)
            host = uri.host
            host == 'fhir.cerner.com' || host&.end_with?('.fhir.cerner.com')
          rescue URI::InvalidURIError
            false
          end

          def find_ndc_entry(entries)
            entry = entries.find do |v|
              system = v[:system] || v['system']
              display = v[:display] || v['display']
              system == 'http://hl7.org/fhir/sid/ndc' && display.present?
            end
            entry ? (entry[:display] || entry['display']) : nil
          end

          def find_first_display_entry(entries)
            entry = entries.find do |v|
              display = v[:display] || v['display']
              display.present?
            end
            entry&.dig(:display) || entry&.dig('display')
          end

          def extract_prefixed_group_name(filtered_codes)
            # Remove the prefix and clean up whitespace
            first_code = filtered_codes.first
            return nil if first_code.nil?

            group_name = first_code[:display] || first_code['display']
            group_name&.delete_prefix('VACCINE GROUP:')&.strip
          end
        end
      end
    end
  end
end
