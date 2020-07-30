# frozen_string_literal: true

module Swagger
  module Requests
    class DebtLetters
      include Swagger::Blocks

      swagger_path '/v0/debt_letters/{id}' do
        operation :get do
          key :description, 'Download a debt letter PDF'
          key :operationId, 'getDebtLetter'
          key :tags, %w[debts]

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Document ID of debt letter'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Debt letter download'

            schema do
              property :data, type: :string, format: 'binary'
            end
          end
        end
      end

      swagger_path '/v0/debt_letters' do
        operation :get do
          key :description, 'Provides an array of debt letter ids and descriptions collected from eFolder'
          key :operationId, 'getDebtLetters'
          key :tags, %w[debts]

          response 200 do
            key :description, 'Successful debt letters lookup'

            schema do
              items do
                property :document_id, type: :string
                property :doc_type, type: :string
                property :type_description, type: :string
                property :received_at, type: :string, format: 'date'
              end
            end
          end
        end
      end
    end
  end
end
