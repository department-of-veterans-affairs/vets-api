# frozen_string_literal: true

module Swagger
  module Requests
    class Notifications
      include Swagger::Blocks

      swagger_path '/v0/notifications' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError

          key :description, 'Create a notification record'
          key :operationId, 'postNotification'
          key :tags, %w[notifications]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'The properties to create a notification record'
            key :required, true

            schema do
              key :required, %i[
                subject
                read
              ]

              property :subject,
                       type: :string,
                       example: 'form_10_10ez',
                       enum: Notification.subjects.keys.sort
              property :read, type: :boolean, example: false, enum: [true, false]
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Notification
            end
          end
        end
      end

      swagger_path '/v0/notifications/{subject}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::RecordNotFoundError

          key :description, "Gets the user's associated notification details"
          key :operationId, 'getNotification'
          key :tags, %w[
            notifications
          ]

          parameter :authorization

          parameter do
            key :name, 'subject'
            key :in, :path
            key :description, 'The subject of the notification (i.e. "form_10_10ez")'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Notification
            end
          end
        end

        operation :patch do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::RecordNotFoundError

          key :description, 'Update an existing Notification record'
          key :operationId, 'patchNotification'
          key :tags, %w[notifications]

          parameter :authorization

          parameter do
            key :name, 'subject'
            key :in, :path
            key :description, 'The subject of the notification (i.e. "form_10_10ez")'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'The properties to update an existing notification record'
            key :required, true

            schema do
              key :required, %i[read]

              property :read, type: :boolean, example: true, enum: [true, false]
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Notification
            end
          end
        end
      end

      swagger_path '/v0/notifications/dismissed_statuses/{subject}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::RecordNotFoundError

          key :description, "Gets the user's most recent dismissed status notification details"
          key :operationId, 'getDismissedStatus'
          key :tags, %w[
            notifications
          ]

          parameter :authorization

          parameter do
            key :name, 'subject'
            key :in, :path
            key :description, 'The subject of the dismissed status notification (i.e. "form_10_10ez")'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :DismissedStatus
            end
          end
        end

        operation :patch do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::RecordNotFoundError

          key :description, 'Update an existing dismissed status notification record'
          key :operationId, 'patchDismissedStatus'
          key :tags, %w[notifications]

          parameter :authorization

          parameter do
            key :name, 'subject'
            key :in, :path
            key :description, 'The subject of the dismissed status notification (i.e. "form_10_10ez")'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'The properties to update an existing dismissed status notification'
            key :required, true

            schema do
              key :required, %i[
                status
                status_effective_at
              ]

              property :status,
                       type: :string,
                       example: 'pending_mt',
                       enum: Notification.statuses.keys.sort
              property :status_effective_at, type: :string, example: '2019-02-25T01:22:00.000Z'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :DismissedStatus
            end
          end
        end
      end

      swagger_path '/v0/notifications/dismissed_statuses' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError

          key :description, 'Create a dismissed status notification record'
          key :operationId, 'postDismissedStatus'
          key :tags, %w[notifications]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'The properties to create a dismissed status notification'
            key :required, true

            schema do
              key :required, %i[
                subject
                status
                status_effective_at
              ]

              property :subject,
                       type: :string,
                       example: 'form_10_10ez',
                       enum: Notification.subjects.keys.sort
              property :status,
                       type: :string,
                       example: 'pending_mt',
                       enum: Notification.statuses.keys.sort
              property :status_effective_at, type: :string, example: '2019-02-25T01:22:00.000Z'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :DismissedStatus
            end
          end
        end
      end
    end
  end
end
