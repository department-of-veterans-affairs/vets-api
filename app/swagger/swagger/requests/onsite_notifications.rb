# frozen_string_literal: true

module Swagger
  module Requests
    class OnsiteNotifications
      include Swagger::Blocks

      swagger_path '/v0/onsite_notifications/{id}' do
        operation :patch do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError

          key :description, 'Update a onsite notification'
          key :operationId, 'updateOnsiteNotification'
          key :tags, %w[
            my_va
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, :onsite_notification
            key :in, :body
            key :description, 'Onsite notification data'
            key :required, true

            schema do
              key :type, :object
              key :required, [:onsite_notification]

              property(:onsite_notification) do
                key :type, :object
                key :required, [:dismissed]

                property(:dismissed, type: :boolean)
              end
            end
          end

          response 404 do
            key :description, 'Record not found'
            schema do
              key :$ref, :Errors
            end
          end

          response 200 do
            key :description, 'Onsite notification updated successfully'

            schema do
              key :type, :object

              property(:data) do
                key :'$ref', :OnsiteNotification
              end
            end
          end
        end
      end

      swagger_path '/v0/onsite_notifications' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, "List a user's onsite notifications"
          key :operationId, 'listOnsiteNotification'
          key :tags, %w[my_va]

          key :produces, ['application/json']

          parameter :authorization
          parameter :optional_page_number
          parameter :optional_page_length
          parameter do
            key :name, :include_dismissed
            key :in, :query
            key :description, 'Whether to include dismissed notifications'
            key :required, false
            key :type, :boolean
          end

          response 200 do
            key :description, 'Array of onsite notifications'

            schema do
              key :type, :object

              property(:data) do
                key :type, :array

                items do
                  key :'$ref', :OnsiteNotification
                end
              end

              property :meta, '$ref': :MetaPagination
            end
          end
        end

        operation :post do
          extend Swagger::Responses::ValidationError

          key :description, 'Create an onsite notification'
          key :operationId, 'addOnsiteNotification'
          key :tags, %w[my_va]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, :Authorization
            key :in, :header
            description = [
              "Use JWT ES256 algorithm to encode payload {user: 'va_notify', iat: send_time, 'exp': send_time + X}",
              "Put token in the header in the format 'Bearer ${token}'"
            ].join("\n")
            key :description, description
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :onsite_notification
            key :in, :body
            key :description, 'Onsite notification data'
            key :required, true

            schema do
              key :type, :object
              key :required, [:onsite_notification]

              property(:onsite_notification) do
                key :type, :object
                key :required, %i[template_id va_profile_id]

                property(:template_id, type: :string, example: 'f9947b27-df3b-4b09-875c-7f76594d766d')
                property(:va_profile_id, type: :string, example: '505193')
              end
            end
          end

          response 403 do
            key :description, 'Not authorized'
            schema do
              key :$ref, :Errors
            end
          end

          response 200 do
            key :description, 'Onsite notification created successfully'

            schema do
              key :type, :object

              property(:data) do
                key :'$ref', :OnsiteNotification
              end
            end
          end
        end
      end
    end
  end
end
