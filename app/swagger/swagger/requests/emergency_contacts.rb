# frozen_string_literal: true

module Swagger::Requests
  class EmergencyContacts
    include Swagger::Blocks

    swagger_path '/v0/emergency_contacts' do
      operation :get do
        extend Swagger::Responses::AuthenticationError

        key :summary, 'Get Emergency Contacts'
        key :description, "Returns a Veteran's Emergency Contacts"
        key :tags, [:emergency_contacts]

        parameter :authorization

        response 200 do
          key :description, 'Successful request'
          schema do
            key :$ref, :EmergencyContacts
          end
        end
      end

      operation :post do
        extend Swagger::Responses::AuthenticationError
        extend Swagger::Responses::UnprocessableEntityError

        key :summary, 'Create Emergency Contact'
        key :description, 'Creates a new Emergency Contact for a Veteran'
        key :tags, [:emergency_contacts]

        parameter :authorization

        parameter name: :body, in: :body do
          schema do
            property :emergency_contact, type: :object do
              key :$ref, :EmergencyContact
            end
          end
        end

        response 200 do
          key :description, 'Successful request'
        end
      end
    end
  end
end
