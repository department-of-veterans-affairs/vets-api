module Swagger
  module Requests
    class EventBusGateway
      include Swagger::Blocks

      swagger_path '/v0/event_bus_gateway/send_email' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Sends an email to a veteran about an event managed by Event Bus Gateway'
          key :operationId, 'sendEmail'
          key :tags, %w[
            event_bus_gateway
          ]

          parameter :template_id

          response 200 do
            key :description, 'Response is OK'
          end
        end
      end
    end
  end
end