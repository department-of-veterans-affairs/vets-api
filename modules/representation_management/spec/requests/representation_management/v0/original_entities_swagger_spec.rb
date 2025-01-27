# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'Original Entities',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  before do
    create(:veteran_organization,
           :with_address,
           name: "Bob Law's Law Firm",
           address_type: 'Domestic',
           address_line1: '123 Main St',
           city: 'Anytown',
           state_code: 'NY',
           zip_code: '12345',
           phone: '123-456-7890')
    create(:veteran_representative,
           :with_address,
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
           email: 'boblaw@example.com')
  end

  path '/representation_management/v0/original_entities' do
    get('Original Entities') do
      tags 'Original Entities'
      consumes 'application/json'
      produces 'application/json'
      operationId 'Original Entities'

      parameter name: :query, in: :query, type: :string, description: 'Search query', example: 'Bob'

      response '200', 'OK' do
        let(:query) { 'Bob' }
        schema type: :array,
               items: {
                 anyOf: [
                   { '$ref' => '#/components/schemas/veteranServiceRepresentative' },
                   { '$ref' => '#/components/schemas/veteranServiceOrganization' }
                 ]
               }
        run_test!
      end
    end
  end
end
