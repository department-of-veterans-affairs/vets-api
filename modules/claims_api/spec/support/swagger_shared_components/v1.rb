# frozen_string_literal: true

# This class exists due to a limitation of the curl generation logic located in the "developer-portal" project.
# That curl generation logic cannot handle Swagger's "$ref" syntax.
# The "$ref" syntax allows you to define common code in a single location within Swagger & then reference where needed.
# This class helps bridge the gap between avoiding duplicated code and keeping the curl generation logic happy.
#
# Example
#  If you use "rswag" to define your API operations and you use a "$ref" in a definition.
#  The generated Swagger output will have an entry like this ::
#    "$ref": "#/components/parameters/veteranSSNHeader"
#  The logic in "developer-portal" can't work with that.
#  So instead, you can do this in your Swagger definition ::
#    'parameter SwaggerSharedComponents::V1.header_params[:veteran_ssn_header]''
#  Then, in the generated Swagger output, you will have an entry like this that "developer-portal" can work with.
#  "parameters": [
#   {
#     "in": "header",
#     "name": "X-VA-SSN",
#     "required": false,
#     "description": "Veteran SSN if consumer is representative",
#     "schema": {
#       "type": "string"
#     }
#   }
# ]

module SwaggerSharedComponents
  class V1
    def self.header_params # rubocop:disable Metrics/MethodLength
      {
        veteran_ssn_header: {
          in: :header,
          type: :string,
          name: 'X-VA-SSN',
          required: false,
          description: 'Veteran SSN if consumer is representative'
        },
        veteran_first_name_header: {
          in: :header,
          type: :string,
          name: 'X-VA-First-Name',
          required: false,
          description: 'Veteran first name if consumer is representative'
        },
        veteran_last_name_header: {
          in: :header,
          type: :string,
          name: 'X-VA-Last-Name',
          required: false,
          description: 'Veteran last name if consumer is representative'
        },
        veteran_birth_date_header: {
          in: :header,
          type: :string,
          name: 'X-VA-Birth-Date',
          required: false,
          description: 'Veteran birthdate if consumer is representative, in iso8601 format'
        },
        key_inflection_header: {
          in: :header,
          type: :string,
          name: 'X-Key-Inflection',
          required: false,
          description: 'Choose desired key structure for response'
        },
        oauth_token_header: {
          in: :header,
          type: :string,
          name: 'Authorization',
          required: true,
          description: 'OAuth token'
        }
      }
    end

    def self.body_examples # rubocop:disable Metrics/MethodLength
      {
        intent_to_file: {
          in: :body,
          name: 'data',
          required: true,
          description: 'JSON API Payload of Veteran being submitted',
          schema: {
            type: :object,
            required: ['data'],
            properties: {
              data: {
                type: :object,
                required: ['attributes'],
                example:
                JSON.parse(
                  File.read(
                    Rails.root.join('modules', 'claims_api', 'config', 'post_examples', '0966.json')
                  )
                ),
                properties: {
                  attributes: JSON.parse(
                    File.read(
                      Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '0966.json')
                    )
                  )
                }
              }
            }
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
                required: ['attributes'],
                example:
                JSON.parse(
                  File.read(
                    Rails.root.join('modules', 'claims_api', 'config', 'post_examples', '526.json')
                  )
                ),
                properties: {
                  attributes: JSON.parse(
                    File.read(
                      Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '526.json')
                    )
                  )
                }
              }
            }
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
                  File.read(
                    Rails.root.join('modules', 'claims_api', 'config', 'post_examples', '2122.json')
                  )
                ),
                properties: {
                  attributes: JSON.parse(
                    File.read(
                      Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '2122.json')
                    )
                  )
                }
              }
            }
          }
        }
      }
    end
  end
end
