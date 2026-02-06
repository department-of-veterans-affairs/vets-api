# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'

RSpec.describe 'Form 21-4192 API', openapi_spec: 'config/openapi/openapi.json', type: :request do
  before do
    host! Settings.hostname
    allow(SecureRandom).to receive(:uuid).and_return('12345678-1234-1234-1234-123456789abc')
    allow(Time).to receive(:current).and_return(Time.zone.parse('2025-01-15 10:30:00 UTC'))
  end

  # Shared example for validation failure
  shared_examples 'validates schema and returns 422' do
    it 'returns a 422 when request fails schema validation' do |example|
      submit_request(example.metadata)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # Shared test data
  let(:valid_form_data) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form214192', 'valid_form.json').read) }
  let(:invalid_form_data) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form214192', 'invalid_form.json').read) }

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

        let(:form_data) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form214192', 'valid_form.json').read) }

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

        let(:form_data) { invalid_form_data }

        include_examples 'validates schema and returns 422'
      end
    end
  end

  path '/v0/form214192/download_pdf' do
    post 'Download PDF for Form 21-4192' do
      tags 'benefits_forms'
      operationId 'downloadForm214192Pdf'
      consumes 'application/json'
      produces 'application/pdf'
      description 'Generate and download a filled PDF for Form 21-4192 (Request for Employment Information)'

      parameter name: :form_data, in: :body, required: true, schema: Openapi::Requests::Form214192::FORM_SCHEMA

      # Success response - PDF file
      response '200', 'PDF generated successfully' do
        produces 'application/pdf'
        schema type: :string, format: :binary

        let(:form_data) { valid_form_data }

        it 'returns a PDF file' do |example|
          submit_request(example.metadata)
          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq('application/pdf')
          expect(response.headers['Content-Disposition']).to include('attachment')
          expect(response.headers['Content-Disposition']).to include('.pdf')
        end
      end

      response '422', 'Unprocessable Entity - schema validation failed' do
        produces 'application/json'
        schema '$ref' => '#/components/schemas/Errors'

        let(:form_data) { invalid_form_data }

        include_examples 'validates schema and returns 422'
      end

      response '400', 'Bad Request - invalid JSON' do
        produces 'application/json'
        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string },
                       detail: { type: :string },
                       status: { type: :string }
                     }
                   }
                 }
               }

        let(:form_data) { 'invalid-json-string' }

        it 'returns a 400 when JSON is malformed' do
          # This test would require manually sending bad JSON, which rswag makes difficult
          # Skipping actual execution but documenting the response format
          skip 'Requires manual JSON manipulation outside rswag framework'
        end
      end

      response '500', 'Internal Server Error - PDF generation failed' do
        produces 'application/json'
        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string },
                       detail: { type: :string },
                       status: { type: :string }
                     }
                   }
                 }
               }

        let(:form_data) { valid_form_data }

        it 'returns a 500 when PDF generation fails' do |example|
          # Mock a PDF generation failure
          allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError.new('PDF generation error'))
          submit_request(example.metadata)
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end
end
