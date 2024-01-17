# frozen_string_literal: true

require 'va_profile/models/associated_person'

module Swagger::Schemas
  class Contacts
    include Swagger::Blocks

    swagger_schema :Contacts do
      key :required, [:data]
      property :data, type: :array do
        items do
          property :id, type: :string, example: 'dbbf9a58-41e5-40c0-bdb5-fc1407aa1f05'
          property :type, type: :string
          property :attributes do
            key :$ref, :Contact
          end
        end
      end
    end

    swagger_schema :Contact do
      key :required, %i[contact_type given_name family_name primary_phone]
      property :contact_type, type: :string, enum: VAProfile::Models::AssociatedPerson::CONTACT_TYPES
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
