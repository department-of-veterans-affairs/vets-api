# frozen_string_literal: true

module SwaggerSharedComponents
  class V2 # rubocop:disable Metrics/ClassLength
    def self.body_examples # rubocop:disable Metrics/MethodLength
      veteran_identifier_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'veteran_identifier',
          'request.json'
        ).read
      )

      veteran_identifier_json_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'veteran_identifier',
          'example.json'
        ).read
      )

      intent_to_file_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'intent_to_file',
          'request.json'
        ).read
      )

      intent_to_file_request_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'intent_to_file',
          'example.json'
        ).read
      )

      disability_compensation_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          '526.json'
        ).read
      )

      disability_compensation_request_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'disability_compensation',
          'example.json'
        ).read
      )

      disability_compensation_generate_pdf_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'generate_pdf_526.json'
        ).read
      )

      disability_compensation_generate_pdf_request_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'disability_compensation',
          'generate_pdf_example.json'
        ).read
      )

      power_of_attorney_2122a_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          '2122a.json'
        ).read
      )

      power_of_attorney_2122a_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'spec',
          'fixtures',
          'v2',
          'veterans',
          'power_of_attorney',
          '2122a',
          'valid.json'
        ).read
      )

      power_of_attorney_2122_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          '2122.json'
        ).read
      )

      power_of_attorney_2122_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'spec',
          'fixtures',
          'v2',
          'veterans',
          'power_of_attorney',
          '2122',
          'valid.json'
        ).read
      )

      power_of_attorney_request_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'poa_request.json'
        ).read
      )

      power_of_attorney_request_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'spec',
          'fixtures',
          'v2',
          'veterans',
          'power_of_attorney',
          'request_representative',
          'valid_no_claimant.json'
        ).read
      )

      evidence_waiver_submission_request_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          '5103.json'
        ).read
      )

      evidence_waiver_submission_request_body_example = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'spec',
          'fixtures',
          'v2',
          'veterans',
          '5103',
          'form_5103_api.json'
        ).read
      )

      {
        veteran_identifier: {
          in: :body,
          name: 'data',
          required: true,
          description: 'Unique attributes of veteran.',
          schema: {
            type: :object,
            required: veteran_identifier_json_schema['required'],
            properties: veteran_identifier_json_schema['properties'],
            example: veteran_identifier_json_body_example
          }
        },
        intent_to_file: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: intent_to_file_json_schema['required'],
            properties: intent_to_file_json_schema['properties'],
            example: intent_to_file_request_body_example
          }
        },
        disability_compensation: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes', disability_compensation_json_schema['required']],
                properties: {
                  attributes: disability_compensation_json_schema
                }
              }
            },
            example: disability_compensation_request_body_example
          }
        },
        disability_compensation_generate_pdf: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes', disability_compensation_generate_pdf_json_schema['required']],
                properties: {
                  attributes: disability_compensation_generate_pdf_json_schema
                }
              }
            },
            example: disability_compensation_generate_pdf_request_body_example
          }
        },
        power_of_attorney: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes'],
                example:
                JSON.parse(
                  Rails.root.join('modules', 'claims_api', 'config', 'post_examples', '2122.json').read
                ),
                properties: {
                  attributes: JSON.parse(
                    Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '2122.json').read
                  )
                }
              }
            }
          }
        },
        power_of_attorney_2122a: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes', power_of_attorney_2122a_json_schema['required']],
                properties: {
                  attributes: power_of_attorney_2122a_json_schema
                }
              }
            },
            example: power_of_attorney_2122a_body_example
          }
        },
        power_of_attorney2122: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes', power_of_attorney_2122_json_schema['required']],
                properties: {
                  attributes: power_of_attorney_2122_json_schema
                }
              }
            },
            example: power_of_attorney_2122_body_example
          }
        },
        power_of_attorney_request: {
          in: :body,
          name: 'data',
          required: true,
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes', power_of_attorney_request_json_schema['required']],
                properties: {
                  attributes: power_of_attorney_request_json_schema
                }
              }
            },
            example: power_of_attorney_request_body_example
          }
        },
        evidence_waiver_submission_request: {
          in: :body,
          name: 'data',
          required: false,
          schema: {
            type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  attributes: evidence_waiver_submission_request_json_schema
                }
              }
            },
            example: evidence_waiver_submission_request_body_example
          }
        }
      }
    end

    def self.schemas # rubocop:disable Metrics/MethodLength
      disability_compensation_json_schema = JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          '526.json'
        ).read
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
