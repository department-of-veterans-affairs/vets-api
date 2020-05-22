# frozen_string_literal: true

# rubocop:disable Layout/LineLength
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
              key :required, %i[data]
              property :data, type: :object do
                key :required, %i[id type attributes]
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  key :required, %i[preferences]
                  property :preferences do
                    key :type, :array
                    items do
                      key :required, %i[code title preference_choices]
                      property :code, type: :string
                      property :title, type: :string
                      property :preference_choices do
                        key :type, :array
                        key :description, 'Array of PreferenceChoice#codes that the user selected for the associated Preference'
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

      swagger_path '/v0/user/preferences/{code}/delete_all' do
        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Deletes all of the current user\'s UserPreference records for a given Preference code'
          key :operationId, 'deleteAlUserPreferences'
          key :tags, %w[preferences]

          parameter :authorization

          response 200 do
            key :description, 'All UserPreference records for given code have been deleted'
            schema do
              property :data, type: :object do
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  property :preference_code, type: :string
                  property :user_preferences do
                    key :type, :array
                    key :description, 'An empty array'
                    items do
                      key :type, :string
                    end
                    key :example, []
                  end
                end
              end
            end
          end

          response 404 do
            key :description, 'Preference not found. No data was modified.'
            schema do
              key :'$ref', :Errors
            end
          end

          response 422 do
            key :description, 'UserPreferences not deleted. No data was modified.'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

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

          response 400 do
            key :description, 'Bad request'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status]
                  property :title, type: :string, example: 'Missing parameter'
                  property :detail,
                           type: :string,
                           example: 'The required parameter "user_preferences", is missing'
                  property :code, type: :string, example: '108'
                  property :status, type: :string, example: '400'
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

          response 422 do
            key :description, 'Unprocessable Entity'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status]
                  property :title, type: :string, example: 'Unprocessable Entity'
                  property :detail,
                           type: :string,
                           example: 'Experienced ActiveRecord::RecordNotDestroyed with this error...'
                  property :code, type: :string, example: '422'
                  property :status, type: :string, example: '422'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/user/preferences' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          key :description, 'Retrieve a user\'s UserPreferences'
          key :operationId, 'getUserPreferences'
          key :tags, %w[
            preferences
          ]
          parameter :authorization
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
                        key :description, 'Array of selected PreferenceChoice#codes for the associated Preference'
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
        end
      end

      swagger_schema :Preferences do
        property :data, type: :object do
          key :required, %i[id type attributes]
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :code, type: :string
            property :title, type: :string
            property :preference_choices, type: :array do
              items do
                key :'$ref', :PreferenceChoices
              end
            end
          end
        end
      end

      swagger_schema :PreferenceChoices do
        key :type, :object
        property :code, type: :string
        property :description, type: :string
      end
    end
  end
end
# rubocop:enable Layout/LineLength
