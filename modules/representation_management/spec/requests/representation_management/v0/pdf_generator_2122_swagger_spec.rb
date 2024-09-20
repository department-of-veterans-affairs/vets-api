# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'PDF Generator 21-22', type: :request do
  path '/representation_management/v0/pdf_generator2122' do
    post('Generate a PDF for form 21-22') do
      tags 'PDF Generation'
      consumes 'application/json'
      produces 'application/pdf'
      operationId 'createPdfForm2122'
      # summary 'Generate a PDF for form 21-22'

      parameter name: :pdf_generator2122, in: :body, schema: {
        type: :object,
        properties: {
          organization_name: { type: :string, example: 'Veterans Organization' },
          record_consent: { type: :boolean, example: true },
          consent_address_change: { type: :boolean, example: false },
          consent_limits: {
            type: :array,
            items: { type: :string },
            example: %w[ALCOHOLISM DRUG_ABUSE HIV SICKLE_CELL]
          },
          conditions_of_appointment: {
            type: :array,
            items: { type: :string },
            example: %w[a123 b456 c789]
          },
          claimant: {
            type: :object,
            properties: {
              name: {
                type: :object,
                properties: {
                  first: { type: :string, example: 'John' },
                  middle: { type: :string, example: 'A' },
                  last: { type: :string, example: 'Doe' }
                }
              },
              address: {
                type: :object,
                properties: {
                  address_line1: { type: :string, example: '123 Main St' },
                  address_line2: { type: :string, example: 'Apt 1' },
                  city: { type: :string, example: 'Springfield' },
                  state_code: { type: :string, example: 'IL' },
                  country: { type: :string, example: 'US' },
                  zip_code: { type: :string, example: '62704' },
                  zip_code_suffix: { type: :string, example: '1234' }
                }
              },
              date_of_birth: { type: :string, format: :date, example: '12/31/2000' },
              relationship: { type: :string, example: 'Spouse' },
              phone: { type: :string, example: '1234567890' },
              email: { type: :string, example: 'veteran@example.com' }
            }
          },
          veteran: {
            type: :object,
            properties: {
              insurance_numbers: {
                type: :array,
                items: { type: :string },
                example: %w[123456789 987654321]
              },
              name: {
                type: :object,
                properties: {
                  first: { type: :string, example: 'John' },
                  middle: { type: :string, example: 'A' },
                  last: { type: :string, example: 'Doe' }
                }
              },
              address: {
                type: :object,
                properties: {
                  address_line1: { type: :string, example: '123 Main St' },
                  address_line2: { type: :string, example: 'Apt 1' },
                  city: { type: :string, example: 'Springfield' },
                  state_code: { type: :string, example: 'IL' },
                  country: { type: :string, example: 'US' },
                  zip_code: { type: :string, example: '62704' },
                  zip_code_suffix: { type: :string, example: '1234' }
                }
              },
              ssn: { type: :string, example: '123456789' },
              va_file_number: { type: :string, example: '123456789' },
              date_of_birth: { type: :string, format: :date, example: '12/31/2000' },
              service_number: { type: :string, example: '123456789' },
              service_branch: { type: :string, example: 'Army' },
              service_branch_other: { type: :string, example: 'Other Branch' },
              phone: { type: :string, example: '1234567890' },
              email: { type: :string, example: 'veteran@example.com' }
            }
          }
        },
        required: %w[organization_name record_consent veteran]
      }

      response '200', 'PDF generated successfully' do
        let(:pdf_generator2122) do
          {
            organization_name: 'My Organization',
            record_consent: '',
            consent_address_change: '',
            consent_limits: [],
            claimant: {
              date_of_birth: '1980-01-01',
              relationship: 'Spouse',
              phone: '5555555555',
              email: 'claimant@example.com',
              name: {
                first: 'First',
                middle: 'M',
                last: 'Last'
              },
              address: {
                address_line1: '123 Claimant St',
                address_line2: '',
                city: 'ClaimantCity',
                state_code: 'CC',
                country: 'US',
                zip_code: '12345',
                zip_code_suffix: '6789'
              }
            },
            veteran: {
              ssn: '123456789',
              va_file_number: '987654321',
              date_of_birth: '1970-01-01',
              service_number: '123123456',
              service_branch: 'ARMY',
              phone: '5555555555',
              email: 'veteran@example.com',
              insurance_numbers: [],
              name: {
                first: 'First',
                middle: 'M',
                last: 'Last'
              },
              address: {
                address_line1: '456 Veteran Rd',
                address_line2: '',
                city: 'VeteranCity',
                state_code: 'VC',
                country: 'US',
                zip_code: '98765',
                zip_code_suffix: '4321'
              }
            }
          }
        end
        run_test!
      end

      response '422', 'unprocessable entity response' do
        schema '$ref' => '#/components/schemas/Errors'
        run_test!
      end

      response '500', 'Internal server error' do
        schema '$ref' => '#/components/schemas/Errors'
        run_test!
      end
    end
  end
end
