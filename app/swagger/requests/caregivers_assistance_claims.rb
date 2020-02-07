# frozen_string_literal: true

module Swagger
  module Requests
    class CaregiversAssistanceClaims
      include Swagger::Blocks

      swagger_path '/v0/caregivers_assistance_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a 10-10CG form\\
                             (Application for the Program of Comprehensive Assistance for Family Caregivers)'

          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'The application\'s submission data (formatted in compliance with the 10-10CG schema).'
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
