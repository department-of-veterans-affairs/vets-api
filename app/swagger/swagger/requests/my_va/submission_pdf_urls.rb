# app/controllers/v0/my_va/submission_pdf_urls_controller.rb

# frozen_string_literal: true

module Swagger
  module Requests
    module MyVA
      class SubmissionPdfUrls
        include Swagger::Blocks

        swagger_path '/v0/my_va/submission_pdf_urls' do
          operation :post do
            extend Swagger::Responses::ValidationError

            key :description, 'Request PDF is generated and return the download URL'
            key :operationId, 'postSubmissionPdfUrls'
            key :tags, %w[my_va]

            parameter :authorization

            key :consumes, ['application/json']
            key :produces, ['application/json']

            parameter do
              key :name, :submission
              key :in, :body
              key :description, 'Submission'
              key :required, true

              schema do
                key :type, :object
                key :required, [:submission]

                property(:submission) do
                  key :$ref, :SubmissionPdfUrls
                  key :required, %i[
                    form_id
                    submission_guid
                  ]
                end
              end
            end

            response 200 do
              key :description, 'url of downloadable pdf'

              schema do
                property :url, type: :string, example: 'https://example.com/file1.pdf',
                  description: 'PDF download URL'
              end
            end
          end
        end

        swagger_schema :SubmissionPdfUrls do
          key :type, :object
          key :required, %i[
            form_id
            submission_guid
          ]
          property :form_id,
                  type: :string,
                  example: '21-0845'
          property :submission_guid,
                  type: :string,
                  example: '3b03b5a0-3ad9-4207-b61e-3a13ed1c8b80'
        end
      end
    end
  end
end
