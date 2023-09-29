# frozen_string_literal: true

require 'va_profile/models/associated_person'

module Swagger::Schemas
  class EmergencyContacts
    include Swagger::Blocks

    swagger_schema :EmergencyContacts do
      key :required, [:data]
      property :data, type: :array do
        items do
          property :id, type: :string, example: 'dbbf9a58-41e5-40c0-bdb5-fc1407aa1f05'
          property :type, type: :string, example: 'emergency_contact'
          property :attributes do
            key :$ref, :EmergencyContact
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
