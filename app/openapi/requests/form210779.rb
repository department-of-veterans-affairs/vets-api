# frozen_string_literal: true

require_relative '../../../lib/pdf_fill/forms/va210779'
module Openapi
  module Requests
    class Form210779
      SUBMIT_SCHEMA = {
        type: 'object',
        properties: {
          veteranInformation: {
            type: 'object',
            required: %w[fullName dateOfBirth veteranId],
            description: "SECTION I - VETERAN'S IDENTIFICATION INFORMATION",
            properties: {
              fullName: { :$ref => '#/components/schemas/FirstMiddleLastName' },
              dateOfBirth: {
                type: 'string',
                format: 'date',
                example: '1990-01-01'
              },
              ssn: {
                type: 'string',
                example: '123456789',
                nullable: true
              },
              vaFileNumber: {
                type: 'string',
                example: '987654321',
                nullable: true
              }
            }
          },
          claimantInformation: {
            type: 'object',
            required: %w[fullName dateOfBirth veteranId],
            description: "SECTION II - CLAIMANT'S IDENTIFICATION INFORMATION '\
            '(Complete this section ONLY IF the claimant is NOT the veteran)",
            properties: { fullName: { :$ref => '#/components/schemas/FirstMiddleLastName' },
                          dateOfBirth: {
                            type: 'string',
                            format: 'date',
                            example: '1992-05-15',
                            nullable: true
                          },

                          ssn: {
                            type: 'string',
                            example: '987654321',
                            nullable: true
                          },
                          vaFileNumber: {
                            type: 'string',
                            example: '123456789',
                            nullable: true
                          } }

          },
          nursingHomeInformation: {
            type: 'object',
            required: %w[nursingHomeName nursingHomeAddress],
            description: 'SECTION III - NURSING HOME INFORMATION',
            properties: { nursingHomeName: {
                            type: 'string',
                            example: 'Sunrise Senior Living'
                          },
                          nursingHomeAddress: { :$ref => '#/components/schemas/SimpleAddress' } }
          },
          generalInformation: {
            type: 'object',
            required: %w[admissionDate
                         medicaidFacility
                         medicaidApplication
                         patientMedicaidCovered
                         certificationLevelOfCare
                         nursingOfficialName
                         nursingOfficialTitle
                         nursingOfficialPhoneNumber],
            description: 'SECTION IV - GENERAL INFORMATION (To be completed by a Nursing Home Official)',
            properties: {
              admissionDate: {
                type: 'string',
                format: 'date',
                example: '2024-01-01'
              },
              medicaidFacility: {
                type: 'boolean',
                example: true
              },
              medicaidApplication: {
                type: 'boolean',
                example: true
              },
              patientMedicaidCovered: {
                type: 'boolean',
                example: true
              },
              medicaidStartDate: {
                type: 'string', format: 'date',
                example: '2024-02-01'
              },
              monthlyCosts: {
                type: 'string',
                example: '3000.00',
                pattern: '^\d+(\.\d+)?$'
              },
              certificationLevelOfCare: {
                type: 'string',
                description: 'I CERTIFY THAT THE CLAIMANT IS A PATIENT IN THIS FACILITY BECAUSE OF MENTAL OR PHYSICAL' \
                             ' DISABILITY AND IS RECEIVING:',
                example: 'skilled',
                enum: PdfFill::Forms::Va210779::LEVEL_OF_CARE
              },
              nursingOfficialName: {
                type: 'string',
                description: "NURSING HOME OFFICIAL'S NAME (First and Last)",
                example: 'Dr. Sarah Smith'
              },
              nursingOfficialTitle: {
                type: 'string',
                example: 'Director of Nursing'
              },
              nursingOfficialPhoneNumber: {
                type: 'string',
                example: '555-789-0123',
                maxLength: 10,
                format: "^\d{9}$"
              },
              nursingOfficialInternationalPhoneNumber: {
                type: 'string',
                example: '+4 9555-789-0123'
              },
              signature:
              { type: 'string',
                example: 'Dr. Sarah Smith',
                minLength: 1 },
              dateSigned: {
                type: 'string',
                format: 'date',
                example: '1990-01-01'
              }
            }
          }
        }
      }.freeze
    end
  end
end
