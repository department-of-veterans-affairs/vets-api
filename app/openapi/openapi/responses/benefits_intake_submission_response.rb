# frozen_string_literal: true

module Openapi
  module Responses
    class BenefitsIntakeSubmissionResponse
      # Valid response from Benefits Intake API (called via Lighthouse::SubmitBenefitsIntakeClaim)
      BENEFITS_INTAKE_SUBMISSION_RESPONSE = {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string, example: 'saved_claims' },
              attributes: {
                type: :object,
                properties: {
                  submitted_at: {
                    type: :string,
                    format: 'date-time',
                    description: 'ISO 8601 timestamp of when the form was submitted'
                  },
                  regional_office: {
                    type: :array,
                    items: { type: :string },
                    description: 'Array of strings representing the regional office address',
                    example: [
                      'Department of Veterans Affairs',
                      'Pension Management Center',
                      'P.O. Box 5365',
                      'Janesville, WI 53547-5365'
                    ]
                  },
                  confirmation_number: {
                    type: :string,
                    description: 'Confirmation number (GUID) for tracking the submission'
                  },
                  guid: {
                    type: :string,
                    description: 'Unique identifier (same as confirmation_number)'
                  },
                  form: {
                    type: :string,
                    description: 'Form identifier (e.g., "21P-530a", "21-4192")'
                  }
                }
              }
            }
          }
        },
        required: [:data]
      }.freeze
    end
  end
end
