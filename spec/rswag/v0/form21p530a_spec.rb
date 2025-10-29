# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'

RSpec.describe 'Form 21P-530a API', openapi_spec: 'public/openapi.json', type: :request do
  before do
    allow(SecureRandom).to receive(:uuid).and_return('12345678-1234-1234-1234-123456789abc')
    allow(Time).to receive(:current).and_return(Time.zone.parse('2025-01-15 10:30:00 UTC'))
  end

  shared_examples 'matches rswag example with status' do |status|
    it "matches rswag example and returns #{status}" do |example|
      submit_request(example.metadata)
      example.metadata[:response][:content] = {
        'application/json' => {
          example: JSON.parse(response.body, symbolize_names: true)
        }
      }
      assert_response_matches_metadata(example.metadata)
      expect(response).to have_http_status(status)
    end
  end

  path '/v0/form21p530a' do
    post 'Submit a 21P-530a form' do
      tags 'benefits_forms'
      operationId 'submitForm21p530a'
      consumes 'application/json'
      produces 'application/json'
      description 'Submit a Form 21P-530a (Application for Burial Allowance - State/Tribal Organizations). ' \
                  'This endpoint is unauthenticated and may be used by cemetery officials.'

      parameter name: :form_data, in: :body, required: true, schema: Openapi::Requests::Form21p530a::FORM_SCHEMA

      # Success response
      response '200', 'Form successfully submitted' do
        schema Openapi::Responses::BenefitsIntakeSubmissionResponse::BENEFITS_INTAKE_SUBMISSION_RESPONSE

        let(:form_data) do
          JSON.parse(
            Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read
          ).with_indifferent_access
        end

        include_examples 'matches rswag example with status', :ok
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

  path '/v0/form21p530a/download_pdf' do
    post 'Download PDF for a submitted 21P-530a form' do
      tags 'benefits_forms'
      operationId 'downloadForm21p530aPdf'
      consumes 'application/json'
      produces 'application/json'
      description 'Download a PDF copy of a submitted Form 21P-530a. This endpoint accepts the same form data ' \
                  'as the submission endpoint. Currently returns a stub message indicating the feature is not ' \
                  'yet implemented.'

      parameter name: :form_data, in: :body, required: true, schema: Openapi::Requests::Form21p530a::FORM_SCHEMA

      response '200', 'PDF download stub response' do
        schema type: :object,
               properties: {
                 message: {
                   type: :string,
                   example: 'PDF download stub - not yet implemented'
                 }
               }

        let(:form_data) do
          JSON.parse(
            Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read
          ).with_indifferent_access
        end

        include_examples 'matches rswag example with status', :ok
      end
    end
  end
end
