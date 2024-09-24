# frozen_string_literal: true

module SwaggerSharedComponents
  class V0
    def self.body_examples # rubocop:disable Metrics/MethodLength
      # veteran_identifier_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'request_bodies',
      #       'veteran_identifier',
      #       'request.json'
      #     )
      #   )
      # )

      # veteran_identifier_json_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'request_bodies',
      #       'veteran_identifier',
      #       'example.json'
      #     )
      #   )
      # )

      # intent_to_file_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'request_bodies',
      #       'intent_to_file',
      #       'request.json'
      #     )
      #   )
      # )

      # intent_to_file_request_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'request_bodies',
      #       'intent_to_file',
      #       'example.json'
      #     )
      #   )
      # )

      # disability_compensation_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       '526.json'
      #     )
      #   )
      # )

      # disability_compensation_request_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'request_bodies',
      #       'disability_compensation',
      #       'example.json'
      #     )
      #   )
      # )

      # disability_compensation_generate_pdf_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'generate_pdf_526.json'
      #     )
      #   )
      # )

      # disability_compensation_generate_pdf_request_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'request_bodies',
      #       'disability_compensation',
      #       'generate_pdf_example.json'
      #     )
      #   )
      # )

      # power_of_attorney_2122a_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       '2122a.json'
      #     )
      #   )
      # )

      # power_of_attorney_2122a_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'spec',
      #       'fixtures',
      #       'v2',
      #       'veterans',
      #       'power_of_attorney',
      #       '2122a',
      #       'valid.json'
      #     )
      #   )
      # )

      # power_of_attorney_2122_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       '2122.json'
      #     )
      #   )
      # )

      # power_of_attorney_2122_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'spec',
      #       'fixtures',
      #       'v2',
      #       'veterans',
      #       'power_of_attorney',
      #       '2122',
      #       'valid.json'
      #     )
      #   )
      # )

      # power_of_attorney_request_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       'poa_request.json'
      #     )
      #   )
      # )

      # power_of_attorney_request_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'spec',
      #       'fixtures',
      #       'v2',
      #       'veterans',
      #       'power_of_attorney',
      #       'request_representative',
      #       'valid_no_claimant.json'
      #     )
      #   )
      # )

      # evidence_waiver_submission_request_json_schema = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'config',
      #       'schemas',
      #       'v2',
      #       '5103.json'
      #     )
      #   )
      # )

      # evidence_waiver_submission_request_body_example = JSON.parse(
      #   File.read(
      #     Rails.root.join(
      #       'modules',
      #       'claims_api',
      #       'spec',
      #       'fixtures',
      #       'v2',
      #       'veterans',
      #       '5103',
      #       'form_5103_api.json'
      #     )
      #   )
      # )

      {
        pdf_generator2122: {
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
      }
    end

    def self.schemas # rubocop:disable Metrics/MethodLength
      disability_compensation_json_schema = JSON.parse(
        File.read(
          Rails.root.join(
            'modules',
            'claims_api',
            'config',
            'schemas',
            'v2',
            '526.json'
          )
        )
      )
      {
        disability_compensation: {
          name: 'data',
          required: ['data'],
          properties: {
            data: {
              type: :object,
              required: %w[id type attributes],
              properties: {
                id: {
                  type: 'string',
                  example: '7d0de77e-b7bd-4db7-a8d9-69a25482c80a'
                },
                type: {
                  type: 'string',
                  example: 'form/526'
                },
                attributes: disability_compensation_json_schema.except('$schema')
              }
            }
          }
        },
        sync_disability_compensation: {
          name: 'data',
          required: ['data'],
          properties: {
            data: {
              type: :object,
              required: %w[id type attributes],
              properties: {
                id: {
                  type: 'string',
                  example: '7d0de77e-b7bd-4db7-a8d9-69a25482c80a'
                },
                type: {
                  type: 'string',
                  example: 'form/8675309'
                },
                attributes: format_response_for_sync_endpoint(disability_compensation_json_schema.except('$schema'))
              }
            }
          }
        }
      }
    end

    def self.format_response_for_sync_endpoint(schema)
      schema['properties'].merge!({ 'claimId' => { 'type' => 'string', 'example' => '600517517' } })
      schema
    end
  end
end
