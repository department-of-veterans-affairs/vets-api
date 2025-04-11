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

          key :description, 'Get a single travel reimbursment claim details'
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
            key :description, 'Successfully retrieved claim details for a user'
            schema do
              key :$ref, :TravelPayClaimDetails
            end
          end
        end
      end

      swagger_path '/travel_pay/v0/claims' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError

          key :description, 'Submit a travel reimbursment claim'
          key :operationId, 'postTravelPayClaim'
          key :tags, %w[travel_pay]

          parameter :authorization

          parameter do
            key :name, :appointmentDateTime
            key :in, :body
            key :description, 'Appointment local start time'
            key :required, true
            schema do
              property :appointmentDateTime do
                key :type, :string
              end
            end
          end

          parameter do
            key :name, :facilityStationNumber
            key :in, :body
            key :description, 'Appointment facility ID'
            key :required, true
            schema do
              property :facilityStationNumber do
                key :type, :string
              end
            end
          end

          parameter do
            key :name, :appointmentType
            key :in, :body
            key :description, 'CompensationAndPensionExamination or Other'
            key :required, true
            schema do
              property :appointmentType do
                key :type, :string
              end
            end
          end

          parameter do
            key :name, :appointmentName
            key :in, :body
            key :description, 'Name of appointment'
            key :required, false
            schema do
              property :appointmentName do
                key :type, :string
              end
            end
          end

          parameter do
            key :name, :isComplete
            key :in, :body
            key :description, 'Whether or not appointment is complete'
            key :required, true
            schema do
              property :isComplete do
                key :type, :boolean
              end
            end
          end

          response 201 do
            key :description, 'Successfully submitted claim for a user'
            schema do
              key :$ref, :TravelPayClaimSummary
            end
          end
        end
      end
    end
  end
end
