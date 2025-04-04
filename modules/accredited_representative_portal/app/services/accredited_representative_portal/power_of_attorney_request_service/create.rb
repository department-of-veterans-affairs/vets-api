# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequestService
    class Create
      ORGANIZATION = PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION
      ACCREDITED_ENTITY_ERROR = 'poa_code can not be blank'

      # @note For the 21-22 pilot:
      #   1. poa_code is required and it is associated with a Veteran::Service::Organization record
      #   2. the holder_type is always an AccreditedOrganization
      def initialize(claimant:, form_data:, poa_code:, registration_number: nil)
        @claimant = claimant
        @form_data = deep_apply!(form_data, 'phone', &method(:sanitize_phone_number))
        @poa_code = poa_code
        @registration_number = registration_number

        @errors = []
      end

      def call
        @errors << ACCREDITED_ENTITY_ERROR if @poa_code.blank?

        if @errors.any?
          {
            errors: @errors
          }
        else
          {
            request: create_poa_request
          }
        end
      rescue => e
        @errors << e.message

        {
          errors: @errors
        }
      end

      private

      def create_poa_request
        request = nil

        ActiveRecord::Base.transaction do
          request = PowerOfAttorneyRequest.new(
            claimant: @claimant,
            power_of_attorney_holder_type: ORGANIZATION,
            accredited_individual_registration_number: @registration_number,
            power_of_attorney_holder_poa_code: @poa_code
          )

          # PowerOfAttorneyForm expects the incoming data to be json, not a hash
          request.build_power_of_attorney_form(data: @form_data.to_json)

          if unresolved_requests.any?
            unresolved_requests.each do |unresolved|
              unresolved.mark_replaced!(request)
            end
          end

          request.save!
          Monitoring.new.track_count('ar.poa.request.count')
        end

        request
      end

      def deep_apply!(data, target_key, &block)
        case data
        when Hash
          data.each do |key, value|
            if key.to_s == target_key && value.is_a?(String)
              data[key] = yield(value)
            else
              deep_apply!(value, target_key, &block)
            end
          end
        when Array
          data.each { |item| deep_apply!(item, target_key, &block) }
        end

        data
      end

      # removes all non-digit characters from the phone number
      def sanitize_phone_number(phone_number)
        phone_number.gsub(/\D/, '') if phone_number.present?
      end

      def unresolved_requests
        @unresolved_requests ||= PowerOfAttorneyRequest.unresolved.where(claimant: @claimant)
      end
    end
  end
end
