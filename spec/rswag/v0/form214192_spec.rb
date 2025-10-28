# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'

RSpec.describe 'Form 21-4192 API', openapi_spec: 'public/openapi.json', type: :request do
  before do
    host! Settings.hostname
    allow(SecureRandom).to receive(:uuid).and_return('12345678-1234-1234-1234-123456789abc')
    allow(Time).to receive(:current).and_return(Time.zone.parse('2025-01-15 10:30:00 UTC'))
  end

  path '/v0/form214192' do
    post 'Submit a 21-4192 form' do
      tags 'benefits_forms'
      operationId 'submitForm214192'
      consumes 'application/json'
      produces 'application/json'
      description 'Submit a Form 21-4192 (Request for Employment Information in Connection with ' \
                  'Claim for Disability Benefits)'

      parameter name: :form_data, in: :body, required: true, schema: Openapi::Requests::Form214192::FORM_SCHEMA

      # Success response
      response '200', 'Form successfully submitted' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string },
                     attributes: {
                       type: :object,
                       properties: {
                         submitted_at: { type: :string, format: 'date-time' },
                         regional_office: {
                           type: :array,
                           items: { type: :string },
                           example: [
                             'Department of Veterans Affairs',
                             'Example Regional Office',
                             'P.O. Box 1234',
                             'Example City, Wisconsin 12345-6789'
                           ]
                         },
                         confirmation_number: { type: :string },
                         guid: { type: :string },
                         form: { type: :string }
                       }
                     }
                   }
                 }
               },
               required: [:data]

        let(:form_data) do
          {
            veteranInformation: {
              fullName: {
                first: 'John',
                last: 'Doe',
                middle: 'A'
              },
              ssn: '123456789',
              dateOfBirth: '1980-01-01',
              address: {
                street: '123 Main St',
                street2: 'Apt 4B',
                city: 'Springfield',
                state: 'IL',
                postalCode: '62701',
                country: 'US'
              }
            },
            employmentInformation: {
              employerName: 'Acme Corp',
              employerAddress: {
                street: '456 Business Blvd',
                street2: nil,
                city: 'Chicago',
                state: 'IL',
                postalCode: '60601',
                country: 'US'
              },
              typeOfWorkPerformed: 'Software Development',
              beginningDateOfEmployment: '2015-06-01'
            }
          }
        end

        it 'returns a successful response with form submission data' do |example|
          submit_request(example.metadata)
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
          assert_response_matches_metadata(example.metadata)
          expect(response).to have_http_status(:ok)
        end
      end

      response '422', 'Unprocessable Entity - schema validation failed' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:form_data) do
          {
            veteranInformation: {
              fullName: { first: 'OnlyFirst' }
            }
          }
        end

        it 'returns a 422 when request body fails schema validation' do |example|
          submit_request(example.metadata)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
