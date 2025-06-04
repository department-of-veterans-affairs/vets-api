# frozen_string_literal: true

module Swagger
  module Requests
    class EventBusGateway
      include Swagger::Blocks

      swagger_path '/v0/event_bus_gateway/send_email' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          key :description, 'Sends an email to a veteran about an event managed by Event Bus Gateway'
          key :operationId, 'sendEmail'
          key :tags, %w[event_bus_gateway]

          parameter :authorization

          parameter do
            key :name, :template_id
            key :in, :body
            key :description, 'VA Notify template ID'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
          end
        end
      end
    end
  end
end
