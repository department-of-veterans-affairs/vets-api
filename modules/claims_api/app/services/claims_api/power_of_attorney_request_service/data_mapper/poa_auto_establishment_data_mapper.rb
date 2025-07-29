# frozen_string_literal: true

require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'
require_relative 'organization_data_mapper'
require_relative 'individual_data_mapper'
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
          '2122a' => ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper,
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
          return {} unless mapper_class

          @mapped_data = mapper_class.map_data

          [@mapped_data, @type]
        end

        private

        def validate_json_schema(form_number = self.class::FORM_NUMBER)
          validator = ClaimsApi::FormSchemas.new(schema_version: 'v2')
          validator.validate!(form_number, form_attributes)
        end

        def form_attributes
          @json_form_data&.dig('data', 'attributes') || {}
        end
      end
    end
  end
end
