# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Form0781
        include Swagger::Blocks

        swagger_schema :Form0781 do
          property :remarks, type: :string
          property :additionalIncidentText, type: :string
          property :additionalSecondaryIncidentText, type: :string
          property :otherInformation, type: :array do
            items type: :string
          end
          property :incidents, type: :array, minItems: 1 do
            items type: :object do
              key :'$ref', :Incident
            end
          end
        end

        swagger_schema :Incident do
          key :required, [:personalAssault]

          property :personalAssault, type: :boolean
          property :medalsCitations, type: :string
          property :incidentDate,
                   type: :string,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::DATE_PATTERN,
                   example: '2019-10-XX'
          property :incidentLocation, type: :object do
            key :'$ref', :IncidentLocation
          end
          property :incidentDescription, type: :string
          property :unitAssigned, type: :string
          property :unitAssignedDates, type: :object do
            key :'$ref', :DateRange
          end
          property :personsInvolved, type: :array do
            items type: :object do
              key :'$ref', :PersonInvolved
            end
          end
          property :sources, type: :array do
            items type: :object do
              key :'$ref', :Source
            end
          end
        end

        swagger_schema :IncidentLocation do
          # See link for country enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
          property :country, type: :string, example: 'USA'
          property :city, type: :string, maxLength: 30, pattern: /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
          # See link for state enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
          property :state, type: :string, example: 'OR'
          property :additionalDetails, type: :string
        end

        swagger_schema :PersonInvolved do
          property :name, type: :object do
            property :first, type: :string
            property :middle, type: :string
            property :last, type: :string
          end
          property :rank, type: :string
          property :injuryDeath, type: :string, enum:
            %w[
              killedInAction
              killedNonBattle
              woundedInAction
              injuredNonBattle
              other
            ]
          property :injuryDeathOther, type: :string
          property :injuryDeathDate,
                   type: :string,
                   pattern: Swagger::Schemas::Form526::Form526SubmitV2::DATE_PATTERN,
                   example: '2019-10-XX'
          property :unitAssigned, type: :string
          property :description, type: :string
        end

        swagger_schema :Source do
          property :name, type: :string
          property :address, type: :object do
            # See link for country enum
            # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
            property :country, type: :string
            property :addressLine1,
                     type: :string,
                     maxLength: 20,
                     pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
            property :addressLine2,
                     type: :string,
                     maxLength: 20,
                     pattern: Swagger::Schemas::Form526::Form526SubmitV2::ADDRESS_PATTERN
            property :city,
                     type: :string,
                     maxLength: 30,
                     pattern: /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
            # See link for state enum
            # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
            property :state, type: :string
            property :zipCode,
                     type: :string,
                     pattern: /^\\d{5}(?:([-\\s]?)\\d{4})?$/
          end
        end
      end
    end
  end
end
