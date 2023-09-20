# frozen_string_literal: true

require 'va_profile/models/associated_person'

module Swagger::Schemas
  class NextOfKin
    include Swagger::Blocks

    swagger_schema :NextOfKins do
      key :required, [:data]

      property :data, type: :object do
        key :required, [:attributes]
        property :attributes, type: :object do
          key :required, [:next_of_kin]
          property :next_of_kin do
            key :type, :array
            items { key :$ref, :NextOfKin }
          end
        end
      end
    end

    swagger_schema :NextOfKin do
      key :required, %i[contact_type given_name family_name primary_phone]
      property :contact_type, type: :string, enum: VAProfile::Models::AssociatedPerson::EC_TYPES
      property :given_name, type: :string
      property :family_name, type: :string
      property :relationship, type: :string
      property :address_line1, type: :string
      property :address_line2, type: :string
      property :address_line3, type: :string
      property :city, type: :string
      property :state, type: :string
      property :zip_code, type: :string
      property :primary_phone, type: :string
    end
  end
end
