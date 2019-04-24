# frozen_string_literal: true

module Swagger
  module Requests
    class Notifications
      include Swagger::Blocks

      swagger_path '/v0/notifications/dismissed_statuses/{subject}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

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
              key :required, [:data]
              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  key :required, %i[subject dismissed_status dismissed_at]
                  property :subject,
                           type: :string,
                           example: 'form_10_10ez',
                           enum: Notification.subjects.keys.sort
                  property :dismissed_status,
                           type: :string,
                           example: 'pending_mt',
                           enum: Notification.statuses.keys.sort
                  property :status_effective_at, type: :string, example: '2019-02-25T01:22:00.000Z'
                  property :dismissed_at, type: :string, example: '2019-02-26T21:20:50.151Z'
                end
              end
            end
          end

          response 404 do
            key :description, 'Record not found'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status]
                  property :title, type: :string, example: 'Record not found'
                  property :detail,
                           type: :string,
                           example: 'The record identified by form_10_10ez could not be found'
                  property :code, type: :string, example: '404'
                  property :status, type: :string, example: '404'
                end
              end
            end
          end
        end
      end
    end
  end
end
