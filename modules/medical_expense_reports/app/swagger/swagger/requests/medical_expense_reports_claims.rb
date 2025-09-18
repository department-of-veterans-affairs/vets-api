# frozen_string_literal: true

module Swagger
  module Requests
    class MedicalExpenseReportsClaims
      include Swagger::Blocks

      swagger_path '/v0/form8416' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a medical expense report'
          key :operationId, 'addMedicalExpenseReportsClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Medical expense report form data'
            key :required, true

            schema do
              key :type, :string
            end
          end
        end
      end
    end
  end
end
