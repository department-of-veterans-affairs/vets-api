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
#    'parameter SwaggerSharedComponents.header_params[:veteran_ssn_header]''
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

class AppealsApi::SwaggerSharedComponents
  # rubocop:disable Metrics/MethodLength, Layout/LineLength
  def self.header_params
    {
      veteran_ssn_header: {
        in: :header,
        type: :string,
        name: 'X-VA-SSN',
        required: true,
        description: 'Veteran\'s SSN'
      },
      veteran_first_name_header: {
        in: :header,
        type: :string,
        name: 'X-VA-First-Name',
        required: true,
        description: 'Veteran\'s first name'
      },
      veteran_middle_initial_header: {
        in: :header,
        type: :string,
        name: 'X-VA-Middle-Initial',
        required: false,
        description: 'Veteran\'s middle initial'
      },
      veteran_last_name_header: {
        in: :header,
        type: :string,
        name: 'X-VA-Last-Name',
        required: true,
        description: 'Veteran\'s last name'
      },
      veteran_birth_date_header: {
        in: :header,
        type: :string,
        name: 'X-VA-Birth-Date',
        required: true,
        description: 'Veteran\'s birth date'
      },
      veteran_file_number_header: {
        in: :header,
        type: :string,
        name: 'X-VA-File-Number',
        required: false,
        description: 'Veteran\'s file number'
      },
      veteran_insurance_policy_number_header: {
        in: :header,
        type: :string,
        name: 'X-VA-Insurance-Policy-Number',
        required: false,
        description: 'Veteran\'s insurance policy number'
      },
      consumer_username_header: {
        in: :header,
        type: :string,
        name: 'X-Consumer-Username',
        required: false,
        description: 'Consumer User Name (passed from Kong)'
      },
      consumer_id_header: {
        in: :header,
        type: :string,
        name: 'X-Consumer-ID',
        required: false,
        description: 'Consumer GUID'
      },
      va_receipt_date: {
        in: :header,
        type: :string,
        name: 'X-VA-Receipt-Date',
        required: true,
        description: '(yyyy-mm-dd) In order to determine contestability of issues, the receipt date of a hypothetical Decision Review must be specified.'
      }
    }
  end
  # rubocop:enable Metrics/MethodLength, Layout/LineLength

  def self.response_schemas # rubocop:disable Metrics/MethodLength
    {
      hlr_response_schema: {
        type: :object,
        properties: {
          data: {
            properties: {
              id: {
                type: :string,
                pattern: '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
              },
              type: {
                type: :string,
                enum: ['higherLevelReview']
              },
              attributes: {
                properties: {
                  status: {
                    type: :string,
                    example: AppealsApi::HlrStatus::V2_STATUSES.first,
                    enum: AppealsApi::HlrStatus::V2_STATUSES
                  },
                  updatedAt: {
                    type: :string,
                    pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
                  },
                  createdAt: {
                    type: :string,
                    pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
                  },
                  formData: {
                    '$ref' => '#/components/schemas/hlrCreate'
                  }
                }
              }
            },
            required: %w[id type attributes]
          }
        },
        required: ['data']
      },
      nod_response_schema: {
        type: :object,
        properties: {
          data: {
            properties: {
              id: {
                type: :string,
                pattern: '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
              },
              type: {
                type: :string,
                enum: ['noticeOfDisagreement']
              },
              attributes: {
                properties: {
                  status: {
                    type: :string,
                    example: AppealsApi::NodStatus::STATUSES.first,
                    enum: AppealsApi::NodStatus::STATUSES
                  },
                  updatedAt: {
                    type: :string,
                    pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
                  },
                  createdAt: {
                    type: :string,
                    pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
                  },
                  formData: {
                    '$ref' => '#/components/schemas/nodCreateRoot'
                  }
                }
              }
            },
            required: %w[id type attributes]
          }
        },
        required: ['data']
      }
    }
  end
end
