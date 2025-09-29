# frozen_string_literal: true

require 'common/exceptions'
require 'brd/brd'
require 'claims_api/common/exceptions/lighthouse/json_form_validation_error'
require 'claims_api/v2/disability_compensation_shared_service_module'

module ClaimsApi
  module V2
    module AltRevisedDisabilityCompensationValidation
      include DisabilityCompensationSharedServiceModule

      CLAIM_DATE = Time.find_zone!('Central Time (US & Canada)').today.freeze

      def validate_form_526_fes_values(_target_veteran = nil)
        return [] if form_attributes.empty?

        # ensure any provided 'separationLocationCode' values are valid EVSS ReferenceData values
        validate_service_information

        # Return collected errors
        error_collection if @errors
      end

      def validate_service_information
        service_info = form_attributes['serviceInformation']
        return if service_info.blank?

        validate_form_526_location_codes(service_info)
      end

      def validate_form_526_location_codes(service_information)
        service_periods = service_information['servicePeriods']
        any_code_present = service_periods.any? do |service_period|
          service_period['separationLocationCode'].present?
        end

        # only retrieve separation locations if we'll need them
        return unless any_code_present

        separation_locations = retrieve_separation_locations

        if separation_locations.nil?
          # Per FES relaxed validation, if we don't get the locations from BRD we don't produce an error.
          return
        end

        separation_location_ids = separation_locations.pluck(:id).to_set(&:to_s)

        service_periods.each_with_index do |service_period, idx|
          separation_location_code = service_period['separationLocationCode']

          next if separation_location_code.nil? || separation_location_ids.include?(separation_location_code)

          ClaimsApi::Logger.log('separation_location_codes', detail: 'Separation location code not found',
                                                             separation_locations:, separation_location_code:)

          collect_error_messages(
            source: "/serviceInformation/servicePeriods/#{idx}/separationLocationCode",
            detail: "The separation location code (#{idx}) for the claimant is not a valid value."
          )
        end
      end

      # Utility methods grouped at the bottom
      def parse_date_safely(date_string)
        Date.parse(date_string)
      rescue
        nil
      end

      def errors_array
        @errors ||= []
      end

      def collect_error(source:, detail:, title: 'Unprocessable Entity')
        errors_array.push(
          {
            source:,
            title:,
            detail:,
            status: '422'
          }
        )
      end

      def error_collection
        errors_array.uniq! { |e| e[:detail] }
        errors_array
      end

      def collect_error_messages(detail: 'Missing or invalid attribute', source: '/',
                                 title: 'Unprocessable Entity', status: '422')
        errors_array.push({ detail:, source:, title:, status: })
      end
    end
  end
end
