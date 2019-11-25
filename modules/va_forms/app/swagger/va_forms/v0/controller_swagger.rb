# frozen_string_literal: true

module VaForms
  module V0
    class ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms' do
        operation :get do
          security do
            key :apikey, []
          end

          key :summary, 'All VA Forms'
          key :description, 'Returns all VA Forms and their last revision date'
          key :operationId, 'findForms'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Forms'
          ]

          parameter do
            key :name, :query
            key :in, :query
            key :description, 'Query the form number as well as title'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'VaForms index response'
            schema do
              key :type, :object
              key :required, [:data]
              property :data do
                key :'$ref', :FormsIndex
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized Request'
          end

          response 403 do
            key :description, 'Bad API Token'
          end
        end
      end

      swagger_path '/forms/{form_name}' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Find form by form name'
          key :description, 'Returns a single form '
          key :operationId, 'findFormByFormName'
          key :tags, [
            'Forms'
          ]
          parameter do
            key :name, :form_name
            key :in, :path
            key :description, 'The VA form_name of the form being requested'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'VaForm response'
            schema do
              key :type, :object
              key :required, [:data]
              property :data do
                key :'$ref', :FormShow
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized Request'
          end

          response 403 do
            key :description, 'Bad API Token'
          end
        end
      end
    end
  end
end
