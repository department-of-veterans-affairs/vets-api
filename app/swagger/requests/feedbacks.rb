# frozen_string_literal: true

module Swagger
  module Requests
    class Feedbacks
      include Swagger::Blocks

      swagger_path '/v0/feedback' do
        operation :post do
          extend Swagger::Responses::BadRequest

          key :description, 'Submit user feedback about a given page'
          key :operationId, 'postFeedback'
          key :tags, %w[
            feedback
          ]

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Options that makeup the user feedback'
            key :required, true

            schema do
              key :required, %i[target_page description]
              property :target_page do
                key :type, :string
                key :example, '/some/page.html'
                key :description, 'The Vets.gov webpage the user is currently on'
              end
              property :description do
                key :type, :string
                key :example, 'I liked this page very much!'
                key :description, 'Text from user describing their experience'
              end
              property :owner_email do
                key :type, %i[string null]
                key :example, 'joe.smith@gmail.com'
                key :description, 'Optionally provide email of the user'
              end
            end
          end

          response 202 do
            key :description, 'The request has been accepted for processing'
            schema do
              key :required, [:job_id]
              property :job_id, type: :string
            end
          end
        end
      end
    end
  end
end
