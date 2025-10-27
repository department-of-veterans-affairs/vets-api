# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../app/openapi/requests/form210779'

# { post: { responses: { '200': { description: 'Form successfully submitted (stub response)',
#                                 schema: { :$ref => '#/definitions/SavedForm' } } },

RSpec.describe 'Form 21-0779 API', openapi_spec: 'public/openapi.json', type: :request do
  path '/v0/form210779' do
    post 'Submit a 21-0779 form' do
      tags 'benefits_forms'
      operationId 'submitForm210779'
      consumes 'application/json'
      produces 'application/json'
      description 'Submit a 21-0779 form (Request for Nursing Home Information in Connection with Claim for Aid ' \
                  'and Attendance) - STUB IMPLEMENTATION for frontend development'
      # { :$ref => '#/parameters/optional_authorization' },
      parameter name: :form210779, in: :body, required: true, description: 'Form 21-0779 submission data', schema: Openapi::Requests::Form210779::SUBMIT_SCHEMA

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

        let(:form210779) do
          JSON.parse(Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-0779', 'simple.json').read)
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

        response '400', 'Bad Request - schema validation failed' do
          let(:form210779) do
            {
              veteranInformation: {
                fullName: { first: 'OnlyFirst' }
              }
            }
          end

          it 'returns a 400 when request body fails schema validation' do |example|
            submit_request(example.metadata)
            expect(response).to have_http_status(:bad_request)
          end
        end
    end
  end
end
