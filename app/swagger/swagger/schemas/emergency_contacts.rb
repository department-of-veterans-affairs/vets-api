# frozen_string_literal: true

require 'va_profile/models/associated_person'

module Swagger::Schemas
  class EmergencyContacts
    include Swagger::Blocks

    swagger_schema :EmergencyContacts do
      key :required, [:data]

      property :data, type: :object do
        key :required, [:attributes]
        property :attributes, type: :object do
          key :required, [:emergency_contacts]
          property :emergency_contacts do
            key :type, :array
            items { key :$ref, :EmergencyContact }
          end
        end
      end
    end

    swagger_schema :EmergencyContact do
      key :required, %i[contact_type given_name family_name primary_phone]
      property :contact_type, type: :string, enum: VAProfile::Models::AssociatedPerson::EC_TYPES
      property :given_name, type: :string
      property :family_name, type: :string
      property :primary_phone, type: :string
    end
  end
end
