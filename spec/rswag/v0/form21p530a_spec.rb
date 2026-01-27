# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'

RSpec.describe 'Form 21P-530a API', openapi_spec: 'config/openapi/openapi.json', type: :request do
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

        include_examples 'validates schema and returns 422'
      end
    end
  end

  path '/v0/form21p530a/download_pdf' do
    post 'Download PDF for Form 21P-530a' do
      tags 'benefits_forms'
      operationId 'downloadForm21p530aPdf'
      consumes 'application/json'
      produces 'application/pdf'
      description 'Generate and download a filled PDF for Form 21P-530a (Application for Burial Allowance)'

      parameter name: :form_data, in: :body, required: true, schema: Openapi::Requests::Form21p530a::FORM_SCHEMA

      # Success response - PDF file
      response '200', 'PDF generated successfully' do
        produces 'application/pdf'
        schema type: :string, format: :binary

        let(:form_data) do
          JSON.parse(
            Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read
          ).with_indifferent_access
        end

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

        let(:form_data) do
          {
            veteranInformation: {
              fullName: { first: 'OnlyFirst' }
            }
          }
        end

        include_examples 'validates schema and returns 422'
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

        let(:form_data) do
          JSON.parse(
            Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read
          ).with_indifferent_access
        end

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
