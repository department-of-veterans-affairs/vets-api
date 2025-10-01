# frozen_string_literal: true

require_relative '../lighthouse_military_address_validator'
require 'claims_api/partial_date_parser'

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      include LighthouseMilitaryAddressValidator

      IGNORED_DISABILITY_FIELDS = %i[serviceRelevance secondaryDisabilities].freeze

      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @fes_claim = {}
      end

      def map_claim
        claim_attributes
        claim_meta

        wrap_in_request_structure
      end

      private

      def claim_attributes
        veteran_identification_info
        change_of_address
        disabilities
      end

      def claim_meta
        @fes_claim[:claimDate] = @data[:claimDate] if @data[:claimDate].present?
      end

      # a 'disability' is required via the schema
      # 'disabilityActionType' & 'name' are required via the schema
      def disabilities
        disabilities_data = flatten_disabilities(@data[:disabilities])
        @fes_claim[:disabilities] = disabilities_data.map do |disability|
          transform_disability_values!(disability.deep_dup)
        end
      end

      def transform_disability_values!(disability)
        # Remove nil values for the optional fields
        %i[diagnosticCode classificationCode ratedDisabilityId specialIssues].each do |field|
          disability.delete(field) if disability[field].blank?
        end

        # Transform approximate date to FES format
        begin_date = disability[:approximateBeginDate]
        disability[:approximateBeginDate] = ClaimsApi::PartialDateParser.to_fes(begin_date) if begin_date.present?

        # Remove fields not needed for FES
        disability.except(*IGNORED_DISABILITY_FIELDS)
      end

      def flatten_disabilities(disabilities_array)
        disabilities_array.flat_map do |disability|
          primary_disability = disability.dup
          # Remove secondaryDisabilities from primary_disability before adding to list
          secondary_disability_data = primary_disability.delete(:secondaryDisabilities)

          list = [primary_disability]

          if secondary_disability_data.present?
            secondaries = secondary_disability_data.map do |secondary|
              secondary_copy = secondary.dup
              secondary_copy[:name] = secondary[:name]
              secondary_copy[:disabilityActionType] = 'NEW'
              secondary_copy
            end
            list.concat(secondaries)
          end

          list
        end
      end

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @auto_claim.auth_headers['va_eauth_service_transaction_id'],
            veteranParticipantId: extract_veteran_participant_id,
            claimantParticipantId: extract_claimant_participant_id,
            form526: @fes_claim
          }
        }
      end

      def veteran_identification_info
        if address_is_military?(veteran_mailing_address)
          handle_military_address
        else
          handle_domestic_or_international_address
        end
      end

      def handle_military_address
        addr = veteran_mailing_address || {}
        line1 = addr[:addressLine1] || format_address_line(addr[:numberAndStreet], addr[:apartmentOrUnitNumber])
        formatted = {
          addressLine1: line1,
          addressLine2: addr[:addressLine2],
          addressLine3: addr[:addressLine3],
          country: addr[:country] || 'USA',
          militaryPostOfficeTypeCode: military_city(addr),
          militaryStateCode: military_state(addr),
          zipFirstFive: addr[:zipFirstFive],
          zipLastFour: addr[:zipLastFour],
          addressType: 'MILITARY'
        }.compact_blank
        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:currentMailingAddress] = formatted
      end

      def handle_domestic_or_international_address
        addr = veteran_mailing_address || {}
        type = addr[:internationalPostalCode].present? ? 'INTERNATIONAL' : 'DOMESTIC'
        line1 = addr[:addressLine1] || format_address_line(addr[:numberAndStreet], addr[:apartmentOrUnitNumber])
        formatted = {
          addressLine1: line1,
          addressLine2: addr[:addressLine2],
          addressLine3: addr[:addressLine3],
          country: addr[:country] || 'USA',
          zipFirstFive: addr[:zipFirstFive],
          zipLastFour: addr[:zipLastFour],
          addressType: type
        }
        if type == 'INTERNATIONAL'
          formatted[:internationalPostalCode] = addr[:internationalPostalCode]
        else
          formatted[:city] = addr[:city]
          formatted[:state] = addr[:state]
        end
        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:currentMailingAddress] = formatted.compact_blank
      end

      def change_of_address
        change_data = @data.dig(:veteran, :changeOfAddress)
        return if change_data.blank?

        addr = build_change_of_address_base(change_data)
        apply_address_type_fields(addr, change_data)
        addr[:zipFirstFive] = change_data[:zipFirstFive] if change_data[:zipFirstFive].present?
        addr[:zipLastFour] = change_data[:zipLastFour] if change_data[:zipLastFour].present?
        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:changeOfAddress] = addr.compact_blank
      end

      def veteran_mailing_address
        @data.dig(:veteranIdentification, :mailingAddress) ||
          @data.dig(:veteran, :currentMailingAddress)
      end

      def format_address_line(street, unit)
        return street if street.present? && unit.nil?
        return nil if street.blank?

        [street, unit].compact.join(' ')
      end

      def build_change_of_address_base(change_data)
        line1 = change_data[:addressLine1] ||
                format_address_line(change_data[:numberAndStreet], change_data[:apartmentOrUnitNumber])
        {
          addressChangeType: change_data[:typeOfAddressChange],
          beginningDate: change_data[:beginningDate] || change_data.dig(:dates, :beginDate),
          endingDate: change_data[:endingDate] || change_data.dig(:dates, :endDate),
          addressLine1: line1,
          addressLine2: change_data[:addressLine2],
          addressLine3: change_data[:addressLine3],
          country: change_data[:country] || 'USA'
        }.compact_blank
      end

      def apply_address_type_fields(addr, change_data)
        if address_is_military?(change_data)
          addr.merge!(
            militaryPostOfficeTypeCode: military_city(change_data),
            militaryStateCode: military_state(change_data),
            addressType: 'MILITARY'
          )
        elsif change_data[:internationalPostalCode].present?
          addr.merge!(
            internationalPostalCode: change_data[:internationalPostalCode],
            addressType: 'INTERNATIONAL'
          )
        else
          addr.merge!(
            city: change_data[:city],
            state: change_data[:state],
            addressType: 'DOMESTIC'
          )
        end
      end

      def extract_veteran_participant_id
        # Try auth_headers first, then fall back to other sources
        @auto_claim.auth_headers&.dig('va_eauth_pid') ||
          @auto_claim.auth_headers&.dig('participant_id')
      end

      def extract_claimant_participant_id
        if @auto_claim.auth_headers&.dig('dependent', 'participant_id').present?
          @auto_claim.auth_headers.dig('dependent', 'participant_id')
        else
          extract_veteran_participant_id
        end
      end
    end
  end
end
