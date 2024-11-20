# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'Accredited Entities for Appoint',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  path '/representation_management/v0/accredited_entities_for_appoint' do
    get('Accredited Entities for Appoint') do
      tags 'Accredited Entities for Appoint'
      consumes 'application/json'
      produces 'application/json'
      operationId 'accreditedEntitiesForAppoint'

      parameter SwaggerSharedComponents::V0.body_examples[:accredited_entities_for_appoint_parameter]

      response '200', 'OK' do
        let(:accredited_entities_for_appoint) do
          SwaggerSharedComponents::V0.body_examples[:accredited_entities_for_appoint]
        end
        # schema type: :array,
        #        items: {
        #          anyOf: [
        #            #  { '$ref' => '#/components/schemas/veteran_service_representative' },
        #            #  { '$ref' => '#/components/schemas/veteran_service_organization' },
        #            { '$ref' => '#/components/schemas/accredited_individual_schema' },
        #            { '$ref' => '#/components/schemas/accredited_organization_schema' }
        #          ]
        #        }
        schema anyOf: [
          { '$ref' => '#/components/schemas/accredited_individual' },
          { '$ref' => '#/components/schemas/accredited_organization' }
        ]
        run_test!
      end

      # response '422', 'unprocessable entity response' do
      #   let(:accredited_entities_for_appoint) do
      #     params = SwaggerSharedComponents::V0.body_examples[:accredited_entities_for_appoint]
      #     params.delete(:query)
      #     params
      #   end
      #   schema '$ref' => '#/components/schemas/Errors'
      #   run_test!
      # end
    end
  end
end
