# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require 'pdf_fill/forms/va212680'

RSpec.describe 'Form 21-2680 API', openapi_spec: 'public/openapi.json', type: :request do
  path '/v0/form212680/download_pdf' do
    post 'Submit a 21-2680 form' do
      tags 'benefits_forms'
      operationId 'downloadForm212680Pdf'
      consumes 'application/json'
      produces 'application/json'
      description 'Generate and download a pre-filled 21-2680 PDF form (Examination for Housebound Status or' \
                  ' Permanent Need for Regular Aid and Attendance)'

      parameter name: :form212680, in: :body, schema: {
        type: :object,
        properties:
         { veteranInformation: { type: 'object',
                                 required: %w[fullName ssn dateOfBirth],
                                 description: "Section I: VETERAN'S IDENTIFICATION INFORMATION",
                                 properties: {
                                   fullName: { :$ref => '#/components/schemas/FirstMiddleLastName' },
                                   ssn: { type: 'string',
                                          example: '123456789',
                                          description: 'Social Security Number (9 digits)',
                                          pattern: '^\d{9}$',
                                          maxLength: 9,
                                          minLength: 9 },
                                   vaFileNumber: { type: 'string',
                                                   example: '987654321',
                                                   description: 'VA File Number',
                                                   maxLength: 9 },
                                   serviceNumber: { type: 'string',
                                                    example: 'A2999999',
                                                    description: "VETERAN'S SERVICE NUMBER ",
                                                    maxLength: 10,
                                                    nullable: true },
                                   dateOfBirth: { type: 'string',
                                                  format: 'date',
                                                  example: '1950-01-01',
                                                  description: 'Date of Birth' }
                                 } },
           claimantInformation: { type: 'object',
                                  required: %w[fullName relationship address],
                                  description: "Section II: CLAIMANT'S IDENTIFICATION INFORMATION",
                                  properties: {
                                    fullName: { :$ref => '#/components/schemas/FirstMiddleLastName' },
                                    dateOfBirth: { type: 'string',
                                                   format: 'date',
                                                   example: '1950-01-01',
                                                   description: 'Date of Birth' },
                                    ssn: { type: 'string',
                                           example: '123456789',
                                           description: 'Social Security Number (9 digits)',
                                           pattern: '^\d{9}$',
                                           maxLength: 9,
                                           minLength: 9 },
                                    relationship: { type: 'string',
                                                    example: 'spouse',
                                                    description: 'Relationship to veteran',
                                                    enum: PdfFill::Forms::Va212680::RELATIONSHIPS.keys,
                                                    nullable: true },
                                    address: { :$ref => '#/components/schemas/SimpleAddress' },
                                    phoneNumber: { type: 'string',
                                                   example: '5551234567',
                                                   pattern: '^\d{10}$',
                                                   description: 'Phone Number',
                                                   maxLength: 10,
                                                   minLength: 10,
                                                   nullable: true },
                                    internationalPhoneNumber: { type: 'string',
                                                                example: '5551234567',
                                                                description: 'Phone Number',
                                                                nullable: true },
                                    agreeToElectronicCorrespondence: { type: 'boolean',
                                                                       example: true },
                                    email: { type: 'string',
                                             example: 'test@va.gov',
                                             description: 'Email Address',
                                             maxLength: 70,
                                             nullable: true }
                                  } },
           benefitInformation: { type: 'object',
                                 required: ['benefitSelection'],
                                 description: 'SECTION III: CLAIM INFORMATION',
                                 properties: {
                                   benefitSelection: { type: 'string',
                                                       example: 'smc',
                                                       description: 'Type of benefit being claimed',
                                                       enum: PdfFill::Forms::Va212680::BENEFITS.keys }
                                 } },
           additionalInformation: { type: 'object',
                                    description: 'Section IV: IS VETERAN/CLAIMANT HOSPITALIZED?',
                                    required: %w[currentlyHospitalized],
                                    properties: {
                                      currentlyHospitalized: {
                                        type: 'boolean',
                                        example: false,
                                        description: 'Is veteran currently hospitalized?'
                                      },
                                      admissionDate: { type: 'string',
                                                       format: 'date',
                                                       example: '2023-01-01',
                                                       description: 'Date admitted',
                                                       nullable: true },
                                      hospitalName: { type: 'string',
                                                      example: 'VA Medical Center',
                                                      description: 'Name of hospital',
                                                      nullable: true },
                                      hospitalAddress: {
                                        :$ref => '#/components/schemas/SimpleAddress'
                                      }
                                    } },
           veteranSignature: { type: 'object',
                               required: %w[signature date],
                               description: 'Section V: CERTIFICATION AND SIGNATURE',
                               properties: {
                                 signature: { type: 'string',
                                              example: 'John A Doe',
                                              description: 'Signature of veteran or claimant' },
                                 date: { type: 'string',
                                         format: 'date',
                                         example: '2025-10-20',
                                         description: 'Date signed (must be within last 60 days)' }
                               } } }
      }

      # {"422"=>{"description"=>"Unprocessable Entity", "schema"=>{"$ref"=>"#/components/schemas/Errors"}},
      #  "500"=>{"description"=>"Internal server error", "schema"=>{"$ref"=>"#/components/schemas/Errors"}},
      #   "200"=>{"description"=>"PDF file successfully generated and ready for download", "schema"=>{"type"=>"file"}}

      # Success response
      response '200', 'Form successfully submitted' do
        schema type: :string,
               format: :binary,
               description: 'PDF file successfully generated and ready for download'

        let(:form212680) do
          JSON.parse(Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-2680', 'simple.json').read)
        end

        it 'returns a successful pdf response with form submission data' do |example|
          submit_request(example.metadata)
          expect(response).to have_http_status(:ok)
        end
      end

      #   response '400', 'Form invalid' do
      #     schema '$ref' => '#/components/schemas/Errors'
      #     let(:form212680) { {} }

      #     it 'returns a 400response' do |example|
      #       submit_request(example.metadata)
      #       expect(response).to have_http_status(400)
      #       assert_response_matches_metadata(example.metadata)
      #     end
      #   end
    end
  end
end
