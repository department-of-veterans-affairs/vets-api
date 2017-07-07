# frozen_string_literal: true
module Swagger
  module Requests
    class Letters
      include Swagger::Blocks

      swagger_path '/v0/letters' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of available letters for a veteran'
          key :operationId, 'getLetters'
          key :tags, [
            'evss'
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Letters
            end
          end
          response 404 do
            key :description, 'User or letters not found in EVSS'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_schema :Letters do
        key :required, [:data, :meta]

        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string, example: 'evss_gi_bill_status_gi_bill_status_responses'
          property :attributes, type: :object do
            property :first_name, type: :string, example: 'Abraham'
            property :last_name, type: :string, example: 'Lincoln'
            property :name_suffix, type: [:string, :null], example: 'Jr'
            property :date_of_birth, type: [:string, :null], example: '1955-11-12T06:00:00.000+0000'
            property :va_file_number, type: [:string, :null], example: '123456789'
            property :regional_processing_office, type: [:string, :null], example: 'Central Office Washington, DC'
            property :eligibility_date, type: [:string, :null], example: '2004-10-01T04:00:00.000+0000'
            property :delimiting_date, type: [:string, :null], example: '2015-10-01T04:00:00.000+0000'
            property :percentage_benefit, type: [:integer, :null], example: 100
            property :original_entitlement, type: [:integer, :null], example: nil
            property :used_entitlement, type: [:integer, :null], example: 10
            property :remaining_entitlement, type: [:integer, :null], example: 12
            property :enrollments do
              key :type, :array
              items do
                key :'$ref', :Enrollment
              end
            end
          end
        end

        property :meta, description: 'The response from the EVSS service to vets-api', type: :object do
          key :'$ref', :Meta
        end
      end
    end
  end
end
