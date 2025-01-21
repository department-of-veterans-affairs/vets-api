# frozen_string_literal: true

module DecisionReview
  module Schemas
    nod_create_request_schema_json_string = Rails.root.join('lib', 'decision_review', 'schemas',
                                                            'NOD_create_request_body_schema.json').read

    NOD_CREATE_REQUEST = JSON.parse nod_create_request_schema_json_string

    NOD_SHOW_RESPONSE_200 = JSON.parse nod_create_request_schema_json_string

    nod_show_response_200_definitions = {
      'root' => {
        'type' => 'object',
        'properties' => { 'data' => { '$ref' => '#/definitions/nodData' } },
        'required' => ['data'],
        'additionalProperties' => false
      },
      'nodData' => {
        'type' => 'object',
        'properties' => {
          'id' => { '$ref' => '#/definitions/uuid' },
          'type' => { 'type' => 'string', 'enum' => ['noticeOfDisagreement'] },
          'attributes' => {
            'type' => 'object',
            'properties' => {
              'status' => { '$ref' => '#/definitions/nodStatus' },
              'updatedAt' => { '$ref' => '#/definitions/timeStamp' },
              'createdAt' => { '$ref' => '#/definitions/timeStamp' },
              'formData' => { '$ref' => '#/definitions/nodCreateRoot' }
            },
            'required' => %w[status updatedAt createdAt formData],
            'additionalProperties' => false
          }
        },
        'required' => %w[id type attributes],
        'additionalProperties' => false
      },
      'uuid' => {
        'type' => 'string',
        'pattern' => '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
      },
      'timeStamp' => {
        'type' => 'string',
        'pattern' => '\\d{4}(-\\d{2}){2}T\\d{2}(:\\d{2}){2}.\\d{3}Z'
      },
      'nodStatus' => {
        'type' => 'string',
        'enum' => %w[pending submitting submitted success processing error caseflow]
      }
    }
    NOD_SHOW_RESPONSE_200['definitions'].merge!(nod_show_response_200_definitions) do |key, _, _|
      raise StandardError, "duplicate key: #{key}"
    end
    raise unless NOD_SHOW_RESPONSE_200['definitions'].keys.include? 'nodCreateRoot'

    NOD_SHOW_RESPONSE_200['$ref'] = '#/definitions/root'

    NOD_CREATE_RESPONSE_200 = NOD_SHOW_RESPONSE_200

    NOD_CONTESTABLE_ISSUES_RESPONSE_200 = JSON.parse(
      Rails.root.join('lib', 'decision_review', 'schemas',
                      'NOD_contestable_issues_response_200_body_schema.json').read
    )
  end
end
