# frozen_string_literal: true

module Swagger
  module Requests
    class TravelPay
      include Swagger::Blocks

      swagger_path '/travel_pay/claims' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError

          key :description, 'Get a list of travel reimbursment claim summaries'
          key :operationId, 'getTravelPayClaims'
          key :tags, %w[travel_pay]

          parameter :authorization
          parameter do
            key :name, :appt_datetime
            key :in, :query
            key :description, 'The appointment datetime by which to filter claims. Invalid date values return all claims.'
            key :required, false
          end

          response 200 do
            key :description, 'Successfully retrieved claims for a user'
            schema do
              key :$ref, :TravelPayClaims
            end
          end
        end
      end
    end
  end
end
