# frozen_string_literal: true

module Swagger
  module Requests
    class Preferences
      include Swagger::Blocks
      swagger_path '/v0/user/preferences/choices' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns all Preference objects with associated PreferenceChoices'
          key :operationId, 'getPreferences'
          key :tags, %w[preferences]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              property :data, type: :array do
                key :'$ref', :Preferences
              end
            end
          end
        end
      end

      swagger_path '/v0/user/preferences/choices/{code}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns a single Preference with associated PreferenceChoices'
          key :operationId, 'getPreference'
          key :tags, %w[preferences]

          parameter :authorization

          parameter do
            key :name, 'code'
            key :in, :path
            key :description, 'The code for the Preference'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Preferences
            end
          end

          response 404 do
            key :description, 'Not found: Preference record not found'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      # rubocop:disable Metrics/LineLength
      swagger_path '/v0/user/preferences' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Both creates and updates a users UserPreferences'
          key :operationId, 'postUserPreferences'
          key :tags, %w[
            preferences
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Array of Preference and PreferenceChoice selections that the user made'
            key :required, true

            schema do
              key :type, :array
              items do
                key :required, %i[preference user_preferences]
                property :preference, type: :object do
                  key :required, %i[code]
                  property :code, type: :string, description: 'The Preference#code'
                end
                property :user_preferences do
                  key :type, :array
                  key :description, 'Array of the PreferenceChoice#codes that the user selected for the associated Preference'
                  items do
                    key :required, %i[code]
                    property :code, type: :string, description: 'The PreferenceChoice#code'
                  end
                end
              end
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, %i[data]
              property :data, type: :object do
                key :required, %i[id type attributes]
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  key :required, %i[user_preferences]
                  property :user_preferences do
                    key :type, :array
                    items do
                      key :required, %i[code title user_preferences]
                      property :code, type: :string
                      property :title, type: :string
                      property :user_preferences do
                        key :type, :array
                        key :description, 'Array of the PreferenceChoice#codes that the user selected for the associated Preference'
                        items do
                          key :required, %i[code description]
                          property :code, type: :string, description: 'The PreferenceChoice#code'
                          property :description, type: :string, description: 'The PreferenceChoice#description'
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          response 404 do
            key :description, 'Not found: Preference record not found'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
      # rubocop:enable Metrics/LineLength

      swagger_schema :Preferences do
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :code, type: :string
            property :title, type: :string
            property :preference_choices, type: :array do
              key :'$ref', :PreferenceChoices
            end
          end
        end
      end

      swagger_schema :PreferenceChoices do
        property :data, type: :object do
          property :code, type: :string
          property :description, type: :string
        end
      end
    end
  end
end
