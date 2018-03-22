# frozen_string_literal: true

module Swagger
  module Requests
    class Profile
      include Swagger::Blocks

      swagger_path '/v0/profile/alternate_phone' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users alternate phone number information'
          key :operationId, 'getAlternatePhone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PhoneNumber
            end
          end
        end
      end

      swagger_path '/v0/profile/email' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users email address information'
          key :operationId, 'getEmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Email
            end
          end
        end
      end

      swagger_path '/v0/profile/primary_phone' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users primary phone number information'
          key :operationId, 'getPrimaryPhone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PhoneNumber
            end
          end
        end
      end

      swagger_path '/v0/profile/service_history' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a collection of a users military service episodes'
          key :operationId, 'getServiceHistory'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:data]

              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  key :required, [:service_history]
                  property :service_history do
                    key :type, :array
                    items do
                      key :required, %i[branch_of_service begin_date]
                      property :branch_of_service, type: :string, example: 'Air Force'
                      property :begin_date, type: :string, format: :date, example: '2007-04-01'
                      property :end_date, type: :string, format: :date, example: '2016-06-01'
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
end
