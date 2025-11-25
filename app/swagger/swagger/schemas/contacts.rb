# frozen_string_literal: true

require 'va_profile/models/associated_person'

module Swagger::Schemas
  class Contacts
    include Swagger::Blocks

    swagger_schema :Contacts do
      key :required, [:data]
      property :data, type: :array do
        items do
          property :id, type: :string
          property :type, type: :string
          property :attributes do
            key :$ref, :Contact
          end
        end
      end
      property :meta, type: :object, description: 'Upstream response metadata'
    end

    swagger_schema :Contact do
      key :required, %i[contact_type given_name family_name primary_phone]
      property(
        :contact_type,
        type: :string,
        enum: VAProfile::Models::AssociatedPerson::PERSONAL_HEALTH_CARE_CONTACT_TYPES
      )
      property :given_name, type: %i[string null]
      property :family_name, type: %i[string null]
      property :relationship, type: %i[string null]
      property :address_line1, type: %i[string null]
      property :address_line2, type: %i[string null]
      property :address_line3, type: %i[string null]
      property :city, type: %i[string null]
      property :state, type: %i[string null]
      property :zip_code, type: %i[string null]
      property :primary_phone, type: %i[string null]
    end
  end
end
