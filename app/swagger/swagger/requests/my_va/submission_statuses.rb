# app/controllers/v0/my_va/submission_statuses_controller.rb

# frozen_string_literal: true

module Swagger
  module Requests
    module MyVA
      class SubmissionStatuses
        include Swagger::Blocks

        swagger_path '/v0/my_va/submission_statuses' do
          operation :get do
            key :description, 'Get list of submitted forms for the current session'
            key :operationId, 'getSubmissionStatuses'
            key :tags, %w[
              my_va
            ]

            parameter :authorization

            key :produces, ['application/json']

            response 200 do
              key :description, 'submitted forms and statuses'

              schema do
                key :type, :object

                property :data do
                  key :type, :array
                  items do
                    key :required, %i[
                      id
                      type
                      attributes
                    ]
                    property :id, type: :string, example: '3b03b5a0-3ad9-4207-b61e-3a13ed1c8b80',
                                  description: 'Form submission UID'
                    property :type, type: :string, example: 'submission_status', description: 'type of request'
                    property :attributes do
                      key :$ref, :SubmissionStatusAttrs
                    end
                  end
                end
              end
            end

            response 296 do
              key :description, 'submitted forms but errors occured looking up statuses from lighthouse'

              schema do
                key :type, :object
                key :required, %i[data errors]
                property :data do
                  key :type, :array
                  items do
                    key :required, %i[
                      id
                      type
                      attributes
                    ]
                    property :id, type: :string, example: '3b03b5a0-3ad9-4207-b61e-3a13ed1c8b80',
                                  description: 'Form submission UID'
                    property :type, type: :string, example: 'submission_status', description: 'type of request'
                    property :attributes do
                      key :$ref, :SubmissionStatusAttrs
                    end
                  end
                end

                property :errors do
                  key :type, :array
                  items do
                    key :required, %i[
                      status
                      source
                      title
                      detail
                    ]
                    property :status, type: :integer, example: 429, description: 'Error code'
                    property :source, type: :string, example: 'Lighthouse - Benefits Intake API',
                                      description: 'Error source'
                    property :title, type: :string, example: 'Form Submission Status: Too Many Requests',
                                     description: 'Error description'
                    property :detail, type: :string, example: 'API rate limit exceeded', description: 'Error details'
                  end
                end
              end
            end
          end
        end

        swagger_schema :SubmissionStatusAttrs do
          key :type, :object
          key :description, 'submitted form attributes'

          property :id, type: :string, example: '3b03b5a0-3ad9-4207-b61e-3a13ed1c8b80',
                        description: 'Submitted form UID from lighthouse'
          property :detail, type: [:string, 'null'], example: '',
                            description: 'Error details (only when errors are present)'
          property :form_type, type: :string, example: '21-0845', description: 'The type of form'
          property :message, type: [:string, 'null'], example: 'Descriptive message'
          property :status, type: [:string, 'null'], enum: [
            nil,
            'pending',
            'uploaded',
            'received',
            'processing',
            'success',
            'vbms',
            'error',
            'expired'
          ], example: 'received', description: 'The current status of the submission'
          property :created_at, type: :string, example: '2023-12-15T20:40:47.583Z',
                                description: 'The submission record created in VA.gov'
          property :updated_at, type: [:string, 'null'], example: '2023-12-15T20:40:54.474Z',
                                description: 'The last time the submission status was updated'
          property :pdf_support, type: :boolean, example: true,
                                 description: 'True if submission supports archived pdf downloads'
        end
      end
    end
  end
end
