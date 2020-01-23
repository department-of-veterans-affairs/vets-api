# frozen_string_literal: true

module VAOS
  module Schemas
    class CCSupportedSites
      include Swagger::Blocks

      swagger_schema :CCEligibility do
        key :required, [:data]

        property :data, type: :array do
          items do
            key :'$ref', :Eligible
          end
        end
      end

      swagger_schema :Eligible do
        key :required, %i[id type attributes]

        property :id, type: :string
        property :type, type: :string, enum: :va_appointments
        property :attributes, type: :object do
          property :patientRequest, type: :object do
            property :patientIcn, type: :string
            property :serviceType, type: :string
            property :timestamp, type: :string
          end
          property :eligibilityCodes, type: :array do
            key :description, type: :string
            key :code, type: :string
          end
          property :grandfathered, type: :boolean
          property :noFullServiceVaMedicalFacility, type: :boolean
          property :eligible, type: :boolean
        end
      end
    end
  end
end
