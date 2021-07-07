# frozen_string_literal: true

module Swagger
  module Requests
    class CaregiversAssistanceClaims
      include Swagger::Blocks

      swagger_path '/v0/caregivers_assistance_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError

          key :description,
              'Submit a 10-10CG form (Application for the Program of Comprehensive Assistance for Family Caregivers)'

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

          response 200 do
            key :description, 'Form Submitted'

            schema do
              key :required, [:data]

              property :data, type: :object do
                key :required, [:attributes]

                property :id do
                  key :description, 'Number of pages contained in the form'
                  key :type, :string
                  key :example, ''
                end

                property :type do
                  key :description, 'This is always "form1010cg_submissions"'
                  key :type, :string
                  key :example, 'form1010cg_submissions'
                end

                property :attributes, type: :object do
                  key :required, %i[submitted_at confirmation_number]

                  property :submitted_at do
                    key :type, :string
                    key :example, '1973-01-01T05:00:00.000+00:00'
                  end

                  property :confirmation_number do
                    key :type, :string
                    key :example, 294_824
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
