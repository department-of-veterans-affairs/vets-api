# frozen_string_literal: true

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @fes_claim = {}
      end

      def map_claim
        wrap_in_request_structure
      end

      private

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @auto_claim.auth_headers['va_eauth_service_transaction_id'],
            claimantParticipantId: extract_claimant_participant_id,
            form526: @fes_claim
          }
        }
      end

      def extract_claimant_participant_id
        @auto_claim.auth_headers.dig('dependent', 'participant_id')
      end

      def veteran_identification_info
        # this will be the parent method for all the mailing info
      end

      def disability_claim_info

      end

      def military_service_info
      end

      def handle_military_address
        addr = veteran_mailing_address || {}

        # Handle both field formats
        line1 = addr[:addressLine1] || format_address_line(addr[:numberAndStreet], addr[:apartmentOrUnitNumber])

        formatted_addr = {
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
        @fes_claim[:veteran][:currentMailingAddress] = formatted_addr
      end

      def handle_domestic_or_international_address
        addr = veteran_mailing_address || {}
        type = addr[:internationalPostalCode].present? ? 'INTERNATIONAL' : 'DOMESTIC'

        # Handle both field formats
        line1 = addr[:addressLine1] || format_address_line(addr[:numberAndStreet], addr[:apartmentOrUnitNumber])

        formatted_addr = {
          addressLine1: line1,
          addressLine2: addr[:addressLine2],
          addressLine3: addr[:addressLine3],
          country: addr[:country] || 'USA',
          zipFirstFive: addr[:zipFirstFive],
          zipLastFour: addr[:zipLastFour],
          addressType: type
        }

        if type == 'INTERNATIONAL'
          formatted_addr[:internationalPostalCode] = addr[:internationalPostalCode]
        else
          formatted_addr[:city] = addr[:city]
          formatted_addr[:state] = addr[:state]
        end

        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:currentMailingAddress] = formatted_addr.compact_blank
      end

      def change_of_address
        change_data = @data[:changeOfAddress]
        return if change_data.blank?

        addr = build_change_of_address_base(change_data)
        apply_address_type_fields(addr, change_data)

        addr[:zipFirstFive] = change_data[:zipFirstFive] if change_data[:zipFirstFive].present?
        addr[:zipLastFour] = change_data[:zipLastFour] if change_data[:zipLastFour].present?

        @fes_claim[:veteran] ||= {}
        @fes_claim[:veteran][:changeOfAddress] = addr.compact_blank
      end

    end
  end
end
