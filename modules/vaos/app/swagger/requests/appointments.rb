# frozen_string_literal: true

module Swagger
  module Requests
    module VAOS
      class Appointments
        include Swagger::Blocks

        swagger_path '/services/vaos/v0/appointments' do
          operation :get do
            extend Swagger::Responses::AuthenticationError

            key :description, 'returns list of VA online scheduling (VAOS) appointments'
            key :operationId, 'getAppointments'
            key :tags, [
              'appointments'
            ]

            parameter :authorization

            response 200 do
              key :description, 'gets the list of VA online scheduling appointments'
              schema do
                key :'$ref', :UserData
              end
            end

            response 296 do
              key :description, 'Get user data with some external service errors'
              schema do
                allOf do
                  schema do
                    key :'$ref', :UserInternalServices
                  end
                  schema do
                    property :data, type: :object do
                      property :id, type: :string
                      property :type, type: :string
                      property :attributes, type: :object do
                        property :account, type: %i[object null]
                        property :va_profile, type: %i[object null]
                        property :veteran_status, type: %i[object null]
                        property :vet360_contact_information, type: %i[object null]
                      end
                    end
                    property :meta, type: :object do
                      key :required, [:errors]
                      property :errors do
                        key :type, :array
                        items do
                          property :external_service, type: :string
                          property :start_time, type: :string
                          property :end_time, type: %i[string null]
                          property :description, type: :string
                          property :status, type: :integer
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        swagger_schema :UserData, required: %i[data meta] do
          allOf do
            schema do
              key :'$ref', :Vet360ContactInformation
            end
            schema do
              key :'$ref', :UserInternalServices
            end
            schema do
              property :data, type: :object do
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
                  property :account, type: :object do
                    property :account_uuid,
                             type: %w[string null],
                             example: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
                             description: 'A UUID correlating all user identifiers. Intended to become the user\'s UUID.'
                  end
                  property :va_profile, type: :object do
                    property :status, type: :string
                    property :birthdate, type: :string
                    property :family_name, type: :string
                    property :gender, type: :string
                    property :given_names, type: :array do
                      items do
                        key :type, :string
                      end
                    end
                  end
                  property :veteran_status, type: :object do
                    key :required, [:status]
                    property :is_veteran, type: :boolean, example: true
                    property :status, type: :string, enum: %w[OK NOT_AUTHORIZED NOT_FOUND SERVER_ERROR], example: 'OK'
                    property :served_in_military, type: :boolean, example: true
                  end
                end
              end
              property :meta, type: :object do
                key :required, [:errors]
                property :errors, type: :null
              end
            end
          end
        end
      end
    end
  end
end
