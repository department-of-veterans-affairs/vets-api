# frozen_string_literal: true

require 'va_profile/models/address'
require 'va_profile/models/base_address'

module Swagger
  module Schemas
    module Vet360
      class Address
        include Swagger::Blocks
        ADDRESS_FIELD_LIMIT = ::VAProfile::Models::BaseAddress::ADDRESS_FIELD_LIMIT

        swagger_schema :Vet360AddressSuggestion do
          key :type, :object
          key :required, %i[
            address_line1
            city
            country_code_iso3
            address_type
          ]
          property :address_line1,
                   type: :string,
                   example: '1493 Martin Luther King Rd',
                   maxLength: ADDRESS_FIELD_LIMIT
          property :address_line2, type: :string, maxLength: ADDRESS_FIELD_LIMIT
          property :address_line3, type: :string, maxLength: ADDRESS_FIELD_LIMIT
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::DOMESTIC
          property :city, type: :string, example: 'Fulton', maxLength: 100
          property :country_code_iso3,
                   type: :string,
                   example: 'USA',
                   minLength: 3,
                   maxLength: 3
          property :international_postal_code, type: :string, example: '12345'
          property :province, type: :string
          property :state_code,
                   type: :string,
                   example: 'MS',
                   minLength: 2,
                   maxLength: 2
          property :zip_code,
                   type: :string,
                   example: '38843',
                   minLength: 5,
                   maxLength: 5
          property :zip_code_suffix,
                   type: :string,
                   example: '1234',
                   minLength: 4,
                   maxLength: 4
        end

        %i[
          PostVet360DomesticAddress
          PutVet360DomesticAddress
          PostVet360InternationalAddress
          PutVet360InternationalAddress
          PostVet360MilitaryOverseasAddress
          PutVet360MilitaryOverseasAddress
        ].each do |schema|
          swagger_schema schema do
            property :override_validation_key, type: :integer
            property :address_line1,
                     type: :string,
                     example: '1493 Martin Luther King Rd',
                     maxLength: ADDRESS_FIELD_LIMIT,
                     pattern: 'US-ASCII'
            property :address_line2,
                     type: :string,
                     maxLength: ADDRESS_FIELD_LIMIT,
                     pattern: 'US-ASCII'
            property :address_line3,
                     type: :string,
                     maxLength: ADDRESS_FIELD_LIMIT,
                     pattern: 'US-ASCII'
          end
        end

        swagger_schema :PostVet360DomesticAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country_name
            state_code
            zip_code
          ]
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::DOMESTIC
          property :city, type: :string, example: 'Fulton', maxLength: 100
          property :country_name,
                   type: :string,
                   example: 'United States',
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :state_code,
                   type: :string,
                   example: 'MS',
                   minLength: 2,
                   maxLength: 2,
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :zip_code,
                   type: :string,
                   example: '38843',
                   maxLength: 5,
                   pattern: ::VAProfile::Models::Address::VALID_NUMERIC_REGEX.inspect
        end

        swagger_schema :PutVet360DomesticAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country_name
            id
            state_code
            zip_code
          ]
          property :id, type: :integer, example: 1
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::DOMESTIC
          property :city, type: :string, example: 'Fulton', maxLength: 100
          property :country_name,
                   type: :string,
                   example: 'United States',
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :state_code,
                   type: :string,
                   example: 'MS',
                   minLength: 2,
                   maxLength: 2,
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :zip_code,
                   type: :string,
                   example: '38843',
                   maxLength: 5,
                   pattern: ::VAProfile::Models::Address::VALID_NUMERIC_REGEX.inspect
        end

        swagger_schema :PostVet360InternationalAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            international_postal_code
            city
            country_name
          ]
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::INTERNATIONAL
          property :city, type: :string, example: 'Florence', maxLength: 100
          property :country_name,
                   type: :string,
                   example: 'Italy',
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :international_postal_code, type: :string, example: '12345'
        end

        swagger_schema :PutVet360InternationalAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            id
            international_postal_code
            city
            country_name
          ]
          property :id, type: :integer, example: 1
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::INTERNATIONAL
          property :city, type: :string, example: 'Florence', maxLength: 100
          property :country_name,
                   type: :string,
                   example: 'Italy',
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :international_postal_code, type: :string, example: '12345'
        end

        swagger_schema :PostVet360MilitaryOverseasAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country_name
            state_code
            zip_code
          ]
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::MILITARY
          property :city, type: :string, example: 'Fulton', maxLength: 100
          property :country_name,
                   type: :string,
                   example: 'United States',
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :state_code,
                   type: :string,
                   example: 'MS',
                   minLength: 2,
                   maxLength: 2,
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :zip_code,
                   type: :string,
                   example: '38843',
                   maxLength: 5,
                   pattern: ::VAProfile::Models::Address::VALID_NUMERIC_REGEX.inspect
        end

        swagger_schema :PutVet360MilitaryOverseasAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country_name
            id
            state_code
            zip_code
          ]
          property :id, type: :integer, example: 1
          property :address_pou,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_POUS,
                   example: ::VAProfile::Models::Address::RESIDENCE
          property :address_type,
                   type: :string,
                   enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                   example: ::VAProfile::Models::Address::MILITARY
          property :city, type: :string, example: 'Fulton', maxLength: 100
          property :country_name,
                   type: :string,
                   example: 'United States',
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :state_code,
                   type: :string,
                   example: 'MS',
                   minLength: 2,
                   maxLength: 2,
                   pattern: ::VAProfile::Models::Address::VALID_ALPHA_REGEX.inspect
          property :zip_code,
                   type: :string,
                   example: '38843',
                   maxLength: 5,
                   pattern: ::VAProfile::Models::Address::VALID_NUMERIC_REGEX.inspect
        end
      end
    end
  end
end
