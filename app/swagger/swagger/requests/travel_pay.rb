# frozen_string_literal: true

module Swagger
  module Requests
    class TravelPay
      include Swagger::Blocks

      swagger_path '/travel_pay/v0/claims' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of travel reimbursment claim summaries'
          key :operationId, 'getTravelPayClaims'
          key :tags, %w[travel_pay]

          parameter :authorization
          parameter do
            key :name, 'start_date'
            key :in, :query
            key :description, 'The start date of the date range. Defaults to 3 months ago.'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'end_date'
            key :in, :query
            key :description, 'The end date of the date range. Defaults to today.'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'page_number'
            key :in, :query
            key :description, 'Page number to start pagination on. Defaults to 1.'
            key :required, false
            key :type, :integer
          end

          response 200 do
            key :description, 'Successfully retrieved claims for a user with pagination information'

            schema do
              property :data do
                key :type, :array
                items do
                  key :$ref, :TravelPayClaimSummary
                end
              end
              property :metadata do
                key :type, :object
                property :status, type: :integer, example: 200
                property :pageNumber, type: :integer, example: 1
                property :totalRecordCount, type: :integer, example: 85
              end
            end
          end

          response 400 do
            key :description, 'Bad request made'
            schema do
              property :error, type: :string, example: 'Bad Request: Invalid date format'
              property :correlation_id, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
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

          response 400 do
            key :description, 'Missing claim'
            schema do
              property :error, type: :string, example: 'Not Found: No claim with that id'
              property :correlation_id, type: :string, example: '33333333-5555-4444-bbbb-222222444444'
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

      swagger_path '/travel_pay/v0/claims/{claimId}/documents/{docId}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::RecordNotFoundError

          key :description, 'Get a document binary'
          key :operationId, 'getTravelPayDocumentBinary'
          key :tags, %w[travel_pay]

          parameter :authorization

          parameter do
            key :name, 'claimId'
            key :in, :path
            key :description, 'The non-PII/PHI id of a claim (UUID - any version)'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'docId'
            key :in, :path
            key :description, 'The non-PII/PHI id of a document (UUID - any version)'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Successfully retrieved claim details for a user'
            schema do
              key :$ref, :TravelPayDocumentBinary
            end
          end
        end
      end
    end
  end
end
