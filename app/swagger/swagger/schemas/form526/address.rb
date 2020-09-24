# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Address
        include Swagger::Blocks

        swagger_schema :AddressRequiredFields do
          key :required, %i[country city addressLine1]

          # See link for country enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
          property :country, type: :string, example: 'USA'
          property :addressLine1,
                   type: :string,
                   maxLength: 20,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
          property :addressLine2,
                   type: :string,
                   maxLength: 20,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
          property :addressLine3,
                   type: :string,
                   maxLength: 20,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
          property :city,
                   type: :string,
                   maxLength: 30,
                   pattern: /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
          # See link for state enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
          property :state, type: :string, example: 'OR'
        end

        swagger_schema :AddressNoRequiredFields do
          # See link for country enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
          property :country, type: :string, example: 'USA'
          property :addressLine1,
                   type: :string,
                   maxLength: 20,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
          property :addressLine2,
                   type: :string,
                   maxLength: 20,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
          property :addressLine3,
                   type: :string,
                   maxLength: 20,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
          property :city,
                   type: :string,
                   maxLength: 30,
                   pattern: /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
          # See link for state enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
          property :state, type: :string, example: 'OR'
        end
      end
    end
  end
end
