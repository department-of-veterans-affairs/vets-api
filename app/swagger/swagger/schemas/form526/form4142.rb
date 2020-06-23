# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Form4142
        include Swagger::Blocks

        swagger_schema :Form4142 do
          property :limitedConsent, type: :string
          property :providerFacility, type: :array, minItems: 1, maxItems: 100 do
            items type: :object do
              key :'$ref', :ProviderFacility
            end
          end
        end

        swagger_schema :ProviderFacility do
          key :required, %i[
            providerFacilityName
            treatmentDateRange
            providerFacilityAddress
          ]

          property :providerFacilityName, type: :string, minLength: 1, maxLength: 100
          property :treatmentDateRange, type: :array do
            items do
              key :'$ref', :DateRangeAllRequired
            end
          end
          property :providerFaciltiyAddress, type: :object do
            key :required, %i[
              street
              city
              country
              state
              postalCode
            ]

            property :street, type: :string, minLength: 1, maxLength: 20
            property :street2, type: :string, minLength: 1, maxLength: 20
            property :city, type: :string, minLength: 1, maxLength: 30
            property :postalCode,
                     type: :string,
                     pattern: /^\\d{5}(?:([-\\s]?)\\d{4})?$/
            # See link for country enum
            # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
            property :country,
                     type: :string,
                     example: 'USA'
            # See link for state enum
            # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
            property :state,
                     type: :string,
                     example: 'OR'
          end
        end
      end
    end
  end
end
