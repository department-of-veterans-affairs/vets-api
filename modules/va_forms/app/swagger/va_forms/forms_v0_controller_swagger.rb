# frozen_string_literal: true

module VaForms
  class FormsV0ControllerSwagger
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

        response :default do
          key :description, 'unexpected error'
          schema do
            key :type, :object
            key :required, [:errors]
            property :errors do
              key :type, :array
              items do
                key :'$ref', :ErrorModel
              end
            end
          end
        end
      end
    end

    swagger_path '/forms/{id}' do
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
              key :'$ref', :FormsShow
            end
          end
        end

        response :default do
          key :description, 'unexpected error'
          schema do
            key :type, :object
            key :required, [:errors]
            property :errors do
              key :type, :array
              items do
                key :'$ref', :ErrorModel
              end
            end
          end
        end
      end
    end
  end
end
