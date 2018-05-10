# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class ContactInformation
        include Swagger::Blocks

        swagger_schema :Vet360ContactInformation do
          property :data, type: :object do
            property :id, type: :string
            property :type, type: :string
            property :attributes, type: :object do
              property :vet360_contact_information, type: :object do
                property :email, type: :object do
                  property :id, type: :integer, example: 323
                  property :email_address, type: :string, example: 'john@example.com'
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :residential_address, type: :object do
                  property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
                  property :address_line2, type: :string
                  property :address_line3, type: :string
                  property :address_pou, type: :string, example: ::Vet360::Models::Address::RESIDENCE
                  property :address_type,
                    type: :string,
                    enum: ::Vet360::Models::Address::ADDRESS_TYPES,
                    example: ::Vet360::Models::Address::DOMESTIC
                  property :city, type: :string, example: 'Fulton'
                  property :country, type: :string, example: 'United States of America'
                  property :country_code_iso2, type: :string, example: 'US'
                  property :country_code_iso3, type: :string, example: 'USA'
                  property :country_code_fips, type: :string, example: 'US'
                  property :id, type: :integer, example: 123
                  property :international_postal_code, type: :string, example: '54321'
                  property :province, type: :string
                  property :state_abbr, type: :string, example: 'NY'
                  property :zip_code, type: :string, example: '97062'
                  property :zip_code_suffix, type: :string, example: '1234'
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :mailing_address, type: :object do
                  property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
                  property :address_line2, type: :string
                  property :address_line3, type: :string
                  property :address_pou,
                    type: :string,
                    example: ::Vet360::Models::Address::CORRESPONDENCE
                  property :address_type,
                    type: :string,
                    enum: ::Vet360::Models::Address::ADDRESS_TYPES,
                    example: ::Vet360::Models::Address::DOMESTIC
                  property :city, type: :string, example: 'Fulton'
                  property :country, type: :string, example: 'United States of America'
                  property :country_code_iso2, type: :string, example: 'US'
                  property :country_code_iso3, type: :string, example: 'USA'
                  property :country_code_fips, type: :string, example: 'US'
                  property :id, type: :integer, example: 123
                  property :international_postal_code, type: :string, example: '54321'
                  property :province, type: :string
                  property :state_abbr, type: :string, example: 'NY'
                  property :zip_code, type: :string, example: '97062'
                  property :zip_code_suffix, type: :string, example: '1234'
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :mobile_phone, type: :object do
                  property :area_code, type: :string, example: '503'
                  property :country_code, type: :string, example: '1'
                  property :extension, type: :string
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_text_permitted, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::Vet360::Models::Telephone::MOBILE
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :home_phone, type: :object do
                  property :area_code, type: :string, example: '503'
                  property :country_code, type: :string, example: '1'
                  property :extension, type: :string
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_text_permitted, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::Vet360::Models::Telephone::HOME
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :work_phone, type: :object do
                  property :area_code, type: :string, example: '503'
                  property :country_code, type: :string, example: '1'
                  property :extension, type: :string
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_text_permitted, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::Vet360::Models::Telephone::WORK
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :temporary_phone, type: :object do
                  property :area_code, type: :string, example: '503'
                  property :country_code, type: :string, example: '1'
                  property :extension, type: :string
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_text_permitted, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::Vet360::Models::Telephone::TEMPORARY
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end

                property :fax_number, type: :object do
                  property :area_code, type: :string, example: '503'
                  property :country_code, type: :string, example: '1'
                  property :extension, type: :string
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_text_permitted, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::Vet360::Models::Telephone::FAX
                  property :created_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :source_date,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                  property :updated_at,
                    type: :string,
                    format: 'date-time',
                    example: '2018-04-21T20:09:50Z'
                end
              end
            end
          end
        end
      end
    end
  end
end
