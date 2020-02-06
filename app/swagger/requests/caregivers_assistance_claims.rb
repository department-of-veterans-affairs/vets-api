# frozen_string_literal: true

module Swagger
  module Requests
    class CaregiversAssistanceClaims
      include Swagger::Blocks

      swagger_path 'v0/caregivers_assistance_claim' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a Caregiver\'s Assistance Application (Form 10-10CG)'

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'The application\'s form data (10-10CG form data)'
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