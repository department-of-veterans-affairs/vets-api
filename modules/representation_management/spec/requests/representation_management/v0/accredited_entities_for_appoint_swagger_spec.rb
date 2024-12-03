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
           name: "Bob Law's Law Firm",
           poa_code: '123',
           address_type: 'Domestic',
           address_line1: '123 Main St',
           city: 'Anytown',
           state_code: 'NY',
           zip_code: '12345',
           phone: '123-456-7890')
    create(:accredited_individual,
           :with_location,
           first_name: 'Bob',
           last_name: 'Law',
           full_name: 'Bob Law',
           address_type: 'Domestic',
           address_line1: '123 Main St',
           city: 'Anytown',
           country_name: 'USA',
           country_code_iso3: 'USA',
           province: 'New York',
           state_code: 'NY',
           zip_code: '12345',
           phone: '123-456-7890',
           email: 'boblaw@example.com',
           individual_type: 'attorney')
  end

  path '/representation_management/v0/accredited_entities_for_appoint' do
    get('Accredited Entities for Appoint') do
      tags 'Accredited Entities for Appoint'
      consumes 'application/json'
      produces 'application/json'
      operationId 'accreditedEntitiesForAppoint'

      parameter name: :query, in: :query, type: :string, description: 'Search query', example: 'Bob'

      response '200', 'OK' do
        let(:query) { 'Bob' }
        schema type: :array,
               items: {
                 anyOf: [
                   { '$ref' => '#/components/schemas/accreditedIndividual' },
                   { '$ref' => '#/components/schemas/accreditedOrganization' }
                 ]
               }
        run_test!
      end
    end
  end
end
