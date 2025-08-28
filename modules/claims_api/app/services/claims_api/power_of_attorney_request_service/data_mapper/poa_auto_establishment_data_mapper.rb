# frozen_string_literal: true

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

        def initialize(type:, data:)
          @type = type
          @data = data
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
      end
    end
  end
end
