# frozen_string_literal: true

module VAForms
  module V0
    class ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms' do
        operation :get do
          security do
            key :apikey, []
          end

          key :summary, 'Returns an index of all available VA forms. Optionally, pass a ?query parameter to filter forms by form number or title.'
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
            key :description, 'Returns form data based on entered form name.'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'VA Forms index response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :type, :array
                  items do
                    key :$ref, :FormsIndex
                  end
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                property :message do
                  key :type, :string
                  key :example, 'Invalid authentication credentials'
                end
              end
            end
          end

          response 429 do
            key :description, 'Too many requests'
            content 'application/json' do
              schema do
                property :message do
                  key :type, :string
                  key :example, 'API rate limit exceeded'
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/{form_name}' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Find form by form name'
          key :description, 'Returns a single form and the full revision history'
          key :operationId, 'findFormByFormName'
          key :tags, [
            'Forms'
          ]
          parameter do
            key :name, :form_name
            key :in, :path
            key :description, 'The VA form_name of the form being requested. Please note that not all VA forms follow the same format and that the exact form name must passed, including proper placement of prefix and/or hyphens.  '
            key :required, true
            key :example, '10-10EZ'
            schema do
              key :type, :string
            end
          end

          response 200 do
            key :description, 'VA Form Show response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :$ref, :FormShow
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                property :message do
                  key :type, :string
                  key :example, 'Invalid authentication credentials'
                end
              end
            end
          end

          response 404 do
            key :description, 'Not Found'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    property :message do
                      key :type, :string
                      key :example, 'Form not found'
                    end
                  end
                end
              end
            end
          end

          response 429 do
            key :description, 'Too many requests'
            content 'application/json' do
              schema do
                property :message do
                  key :type, :string
                  key :example, 'API rate limit exceeded'
                end
              end
            end
          end
        end
      end
    end
  end
end
