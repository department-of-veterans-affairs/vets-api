# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'Accredited Entities for Appoint',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  before do
    create(:accredited_organization,
           :with_location,
           name: "Bob Law's Law Firm")
    create(:accredited_individual,
           :with_location,
           first_name: 'Bob',
           last_name: 'Law',
           full_name: 'Bob Law')
  end

  path '/representation_management/v0/accredited_entities_for_appoint' do
    get('Accredited Entities for Appoint') do
      tags 'Accredited Entities for Appoint'
      consumes 'application/json'
      produces 'application/json'
      operationId 'accreditedEntitiesForAppoint'

      # parameter SwaggerSharedComponents::V0.body_examples[:accredited_entities_for_appoint_parameter]
      parameter name: :query, in: :query, type: :string, description: 'Search query'

      response '200', 'OK' do
        let(:query) { 'Bob' }
        schema type: :array,
               items: {
                 anyOf: [
                   { '$ref' => '#/components/schemas/accredited_individual' },
                   { '$ref' => '#/components/schemas/accredited_organization' }
                 ]
               }
        run_test!
      end
    end
  end
end
