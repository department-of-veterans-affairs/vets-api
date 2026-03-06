# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

RSpec.describe 'Accredited Organizations',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  before do
    allow(Flipper).to receive(:enabled?).with(:find_a_representative_use_accredited_models).and_return(true)

    create(:accredited_organization,
           poa_code: '123',
           name: 'Organization Name',
           phone: '555-555-5555',
           city: 'Anytown',
           state_code: 'NY',
           zip_code: '12345',
           zip_suffix: '6789',
           can_accept_digital_poa_requests: true)
  end

  path '/representation_management/v0/accredited_organizations' do
    get('Accredited Organizations') do
      tags 'Accredited Organizations'
      produces 'application/json'
      operationId 'accreditedOrganizations'
      description 'Returns all accredited organizations'

      response '200', 'OK' do
        schema type: :array,
               items: { '$ref' => '#/components/schemas/accreditedOrganizationWithLimitedProperties' }
        run_test!
      end
    end
  end
end
