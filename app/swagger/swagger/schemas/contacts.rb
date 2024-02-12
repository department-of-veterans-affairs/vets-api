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
      property :contact_type, type: :string, enum: VAProfile::Models::AssociatedPerson::CONTACT_TYPES
      property :given_name, type: :string
      property :middle_name, type: %w[null string]
      property :family_name, type: :string
      property :relationship, type: %w[null string]
      property :address_line1, type: %w[null string]
      property :address_line2, type: %w[null string]
      property :address_line3, type: %w[null string]
      property :city, type: %w[null string]
      property :state, type: %w[null string]
      property :zip_code, type: %w[null string]
      property :primary_phone, type: :string
    end
  end
end
