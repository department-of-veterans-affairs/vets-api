# frozen_string_literal: true

module PowerOfAttorneyRequestService
  class Create
    INDIVIDUAL = 'AccreditedIndividual'
    ORGANIZATION = 'AccreditedOrganization'
    ACCREDITED_ENTITY_ERROR = 'at least one of registration_number and poa_code is required'
    HOLDER_TYPE_ERROR = 'the holder_type is not an allowed value'
    HOLDER_TYPES = [INDIVIDUAL, ORGANIZATION].freeze

    def initialize(claimant:, form_data:, holder_type: ORGANIZATION, poa_code: nil, registration_number: nil)
      @claimant = claimant
      @form_data = form_data
      @holder_type = holder_type
      @poa_code = poa_code
      @registration_number = registration_number

      @errors = []
    end

    def call
      @errors << ACCREDITED_ENTITY_ERROR unless accredited_entity_arguments_valid?
      @errors << HOLDER_TYPE_ERROR unless holder_type_valid?

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

    def accredited_entity_arguments_valid?
      @registration_number.present? || @poa_code.present?
    end

    def holder_type_valid?
      HOLDER_TYPES.include?(@holder_type)
    end

    def create_poa_request
      request = nil

      ActiveRecord::Base.transaction do
        request = ::AccreditedRepresentativePortal::PowerOfAttorneyRequest.new(
          claimant: @claimant,
          power_of_attorney_holder_type: @holder_type,
          accredited_individual_registration_number: @registration_number,
          power_of_attorney_holder_poa_code: @poa_code
        )

        # PowerOfAttorneyForm expects the incoming data to be json, not a hash
        request.build_power_of_attorney_form(data: @form_data.to_json)

        request.save!
      end

      request
    end
  end
end
