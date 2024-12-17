# frozen_string_literal: true

module Swagger
  module Requests
    class TravelPay
      include Swagger::Blocks

      swagger_path '/travel_pay/v0/claims' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError

          key :description, 'Get a list of travel reimbursment claim summaries'
          key :operationId, 'getTravelPayClaims'
          key :tags, %w[travel_pay]

          parameter :authorization
          parameter do
            key :name, 'appt_datetime'
            key :in, :query
            key :description, 'Filter claim by appt datetimes. Invalid dates return all claims.'
            key :required, false
            key :type, :string
          end

          response 200 do
            key :description, 'Successfully retrieved claims for a user'
            schema do
              key :$ref, :TravelPayClaims
            end
          end
        end
      end

      swagger_path '/travel_pay/v0/claims/{id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::RecordNotFoundError

          key :description, 'Get a single travel reimbursment claim summary'
          key :operationId, 'getTravelPayClaimById'
          key :tags, %w[travel_pay]

          parameter :authorization

          parameter do
            key :name, 'id'
            key :in, :path
            key :description, 'The non-PII/PHI id of a claim (UUID - any version)'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Successfully retrieved claim for a user'
            schema do
              key :$ref, :TravelPayClaimSummary
            end
          end
        end
      end
    end
  end
end
