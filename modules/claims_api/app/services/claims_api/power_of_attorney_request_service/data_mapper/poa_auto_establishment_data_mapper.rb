# frozen_string_literal: true

<<<<<<< HEAD
require_relative 'individual_data_mapper'
=======
>>>>>>> master
require_relative 'organization_data_mapper'
require 'json_schema/json_api_missing_attribute'
require 'claims_api/form_schemas'
require 'json'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class PoaAutoEstablishmentDataMapper
        include ClaimsApi::V2::PowerOfAttorneyValidation
        include ClaimsApi::V2::JsonFormatValidation

        LOG_TAG = 'poa_auto_establishment_data_mapper'
        DATA_MAPPERS = {
          '2122' => ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper
        }.freeze

        def initialize(type:, data:, veteran:)
          @type = type
          @data = data
          @veteran = veteran
        end

        def map_data
          ClaimsApi::Logger.log(
            LOG_TAG, message: 'Starting poa auto establish data mapping.'
          )

          mapper_class = DATA_MAPPERS[@type].new(data: @data)
          return [] unless mapper_class

          @json_form_data = deep_compact(mapper_class.map_data)
          return [] if @json_form_data.blank?

          validate_data

          @json_form_data
        end

        # validate here instead of returning to the controller since we know the form type
        # and have it available here
        def validate_data
          # custom validations, must come first
          @poa_auto_establish_validation_errors = validate_form_2122_and_2122a_submission_values(
            user_profile: nil, veteran_participant_id: @veteran.participant_id, poa_code: @data[:poa_code],
            base: form_type_name
          )
          # JSON validations, all errors, including errors from the custom validations
          # will be raised here if JSON errors exist
          validate_json_schema(@type.upcase)
          # otherwise we raise the errors from the custom validations if no JSON
          # errors exist
          if @claims_api_forms_validation_errors
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError,
                  @claims_api_forms_validation_errors
          end
        end

        private

        def form_type_name
          @type == '2122' ? 'serviceOrganization' : 'representative'
        end

        def validate_json_schema(form_number = self.class::FORM_NUMBER)
          validator = ClaimsApi::FormSchemas.new(schema_version: 'v2')
          validator.validate!(form_number, form_attributes)
        end

        def form_attributes
          @json_form_data&.dig('data', 'attributes') || {}
        end

        def deep_compact(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              nested = deep_compact(v)
              result[k] = nested unless nested.nil? || nested == {}
            end
          when Array
            array = obj.map { |v| deep_compact(v) }.reject { |v| v.nil? || v == {} }
            array.empty? ? nil : array
          else
            obj.nil? ? nil : obj
          end
        end
      end
    end
  end
end
