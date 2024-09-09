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
    end

    swagger_schema :Contact do
      key :required, %i[contact_type given_name family_name primary_phone]
      property(
        :contact_type,
        type: :string,
        enum: VAProfile::Models::AssociatedPerson::PERSONAL_HEALTH_CARE_CONTACT_TYPES
      )
      property :given_name, type: :string
      property :family_name, type: :string
      property :relationship, type: :string, nullable: true
      property :address_line1, type: :string, nullable: true
      property :address_line2, type: :string, nullable: true
      property :address_line3, type: :string, nullable: true
      property :city, type: :string, nullable: true
      property :state, type: :string, nullable: true
      property :zip_code, type: :string, nullable: true
      property :primary_phone, type: :string
    end
  end
end
