# frozen_string_literal: true

module Swagger
  module Requests
    class DigitalDisputes
      include Swagger::Blocks

      swagger_path '/debts_api/v0/digital_disputes' do
        operation :post do
          key :summary, 'Submits digital dispute documents to the Debt Management Center and VBS'
          key :description, "Submits PDF documents for debt disputes to the Debt Management Center.
            Veterans can upload one or more PDF files containing documentation supporting
            their dispute of a debt."
          key :operationId, 'postDigitalDispute'
          key :tags, %w[digital_disputes]
          key :consumes, ['multipart/form-data']

          parameter do
            key :name, :metadata
            key :in, :formData
            key :description,
                'JSON string containing dispute information. Must include a "disputes" array with ' \
                'objects containing: composite_debt_id (string, required), deduction_code (string, required), ' \
                'original_ar (number, required), current_ar (number, required), benefit_type (string, required), ' \
                'dispute_reason (string, required), rcvbl_id (string, optional). ' \
                'Example: {"disputes":[{"composite_debt_id":"71166","deduction_code":"71",' \
                '"original_ar":166.67,"current_ar":120.4,"benefit_type":"CH35",' \
                '"dispute_reason":"I don\'t think I owe this debt to VA"}]}'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'files[]'
            key :in, :formData
            key :description, 'One or more PDF files (maximum 1MB each)'
            key :required, true
            key :type, :file
          end

          response 200 do
            key :description, 'Digital dispute successful submission'
            schema do
              property :message, type: :string
              property :submission_id, type: :string
            end
          end

          response 422 do
            key :description, 'Validation error'
            schema do
              property :errors, type: :object
            end
          end
        end
      end

      swagger_schema :DigitalDisputeMetadata do
        key :required, [:disputes]

        property :disputes, type: :array do
          items do
            key :required, %i[composite_debt_id deduction_code original_ar current_ar benefit_type dispute_reason]
            property :composite_debt_id, type: :string,
                                         description: 'Composite debt identifier'
            property :deduction_code, type: :string,
                                      description: 'Deduction code'
            property :original_ar, type: :number,
                                   description: 'Original accounts receivable amount'
            property :current_ar, type: :number,
                                  description: 'Current accounts receivable amount'
            property :benefit_type, type: :string,
                                    description: 'Type of benefit associated with the debt'
            property :dispute_reason, type: :string,
                                      description: 'Reason for disputing the debt'
            property :rcvbl_id, type: :integer,
                                description: 'Receivable ID (optional)'
          end
        end
      end
    end
  end
end
