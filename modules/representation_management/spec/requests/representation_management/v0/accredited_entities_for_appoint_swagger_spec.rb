# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'Accredited Entities for Appoint',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  path '/representation_management/v0/accredited_entities_for_appoint' do
    get('Generate a PDF for form 21-22') do
      tags 'Accredited Entities for Appoint'
      consumes 'application/json'
      produces 'application/json'
      operationId 'accreditedEntitiesForAppoint'

      parameter SwaggerSharedComponents::V0.body_examples[:accredited_entities_for_appoint_parameter]

      response '200', 'OK' do
        let(:pdf_generator2122) do
          SwaggerSharedComponents::V0.body_examples[:pdf_generator2122]
        end
        run_test!
      end

      response '422', 'unprocessable entity response' do
        let(:pdf_generator2122) do
          params = SwaggerSharedComponents::V0.body_examples[:pdf_generator2122]
          params[:veteran][:name].delete(:first)
          params
        end
        schema '$ref' => '#/components/schemas/Errors'
        run_test!
      end
    end
  end
end
