# frozen_string_literal: true

require_relative 'lighthouse_military_address_validator'

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      include LighthouseMilitaryAddressValidator

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
      end

      def claim_meta
        @fes_claim[:claimDate] = @data[:claimDate] || Time.zone.today.to_s
      end

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @auto_claim.auth_headers['va_eauth_service_transaction_id'],
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

      def veteran_mailing_address
        # V2 format: veteranIdentification.mailingAddress
        # V1 format: veteran.currentMailingAddress
        @data.dig(:veteranIdentification, :mailingAddress) || @data.dig(:veteran, :currentMailingAddress)
      end

      def format_address_line(street, unit)
        # Handle both formats:
        # 1. numberAndStreet + apartmentOrUnitNumber (Claims API format)
        # 2. addressLine1 already combined (test format)
        return street if street.present? && unit.nil?
        return nil if street.blank?

        [street, unit].compact.join(' ')
      end

      def build_change_of_address_base(change_data)
        # Handle both field formats
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
    end
  end
end
