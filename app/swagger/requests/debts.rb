# frozen_string_literal: true

module Swagger
  module Requests
    class Debts
      include Swagger::Blocks

      swagger_path '/v0/debts' do
        operation :get do
          key :description, 'Get data about the user\'s debts'
          key :operationId, 'getDebts'
          key :tags, %w[debts]

          response 200 do
            key :description, 'Debts data'

            schema do
              property :data, type: :object do
              end
            end
          end
        end
      end
    end
  end
end
