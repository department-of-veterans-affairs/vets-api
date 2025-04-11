# frozen_string_literal: true

module Swagger
  module Requests
    class Debts
      include Swagger::Blocks

      swagger_path '/v0/debts' do
        operation :get do
          key :description, 'Provides an array of debt details provided by the Debt Management Center for the veteran.'
          key :operationId, 'getDebts'
          key :tags, %w[debts]

          parameter do
            key :name, :count_only
            key :in, :query
            key :description, 'When true, returns only the count of debts'
            key :required, false
            key :type, :boolean
          end

          response 200 do
            key :description, 'Successful debts lookup'
            schema do
              property :debtsCount, type: :integer,
                                    description: 'Total number of debts (only returned when count_only=true)'
              property :has_dependent_debts, type: :boolean
              property :debts, type: :array do
                items do
                  property :file_number, type: :string
                  property :payee_number, type: :string
                  property :person_entitled, type: :string
                  property :deduction_code, type: :string
                  property :benefit_type, type: :string
                  property :amount_overpaid, type: :string
                  property :amount_withheld, type: :string
                  property :debt_history, type: :array do
                    items do
                      property :date, type: :string
                      property :letter_code, type: :string
                      property :status, type: :string
                      property :description, type: :string
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
