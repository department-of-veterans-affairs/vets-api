# frozen_string_literal: true

require 'va_profile/contact_information/person_response'
require 'va_profile/v2/contact_information/person_response'
require 'va_profile/contact_information/service'
require 'va_profile/v2/contact_information/service'
require 'va_profile/models/address'
require 'va_profile/models/v3/address'
require 'va_profile/models/telephone'
require 'va_profile/models/permission'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

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
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :address_line2, type: %i[string null]
                  property :address_line3, type: %i[string null]
                  property :address_pou, type: :string, example: ::VAProfile::Models::Address::RESIDENCE
                  property :address_type,
                           type: :string,
                           enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                           example: ::VAProfile::Models::Address::DOMESTIC
                  property :bad_address, type: :boolean
                  property :city, type: :string, example: 'Fulton'
                  property :country_code_iso3, type: %i[string], example: 'USA'
                  property :country_code_fips, type: %i[string null], example: 'US'
                  property :id, type: :integer, example: 123
                  property :international_postal_code, type: %i[string null], example: '54321'
                  property :latitude, type: %i[number null], example: 38.901
                  property :longitude, type: %i[number null], example: -77.0347
                  property :province, type: %i[string null]
                  property :state_code, type: :string, example: 'NY'
                  property :zip_code, type: :string, example: '97062'
                  property :zip_code_suffix, type: %i[string null], example: '1234'
                  property :geocode_precision, type: %i[number null], example: 100.0
                  property :geocode_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :address_line2, type: %i[string null]
                  property :address_line3, type: %i[string null]
                  property :address_pou,
                           type: :string,
                           example: ::VAProfile::Models::Address::CORRESPONDENCE
                  property :address_type,
                           type: :string,
                           enum: ::VAProfile::Models::Address::ADDRESS_TYPES,
                           example: ::VAProfile::Models::Address::DOMESTIC
                  property :bad_address, type: :boolean
                  property :city, type: :string, example: 'Fulton'
                  property :country_code_iso3, type: %i[string], example: 'USA'
                  property :country_code_fips, type: %i[string null], example: 'US'
                  property :id, type: :integer, example: 123
                  property :international_postal_code, type: %i[string null], example: '54321'
                  property :latitude, type: %i[number null], example: 38.901
                  property :longitude, type: %i[number null], example: -77.0347
                  property :province, type: %i[string null]
                  property :state_code, type: :string, example: 'NY'
                  property :zip_code, type: :string, example: '97062'
                  property :zip_code_suffix, type: %i[string null], example: '1234'
                  property :geocode_precision, type: %i[number null], example: 100.0
                  property :geocode_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :extension, type: %i[string null]
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::VAProfile::Models::Telephone::MOBILE
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :extension, type: %i[string null]
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::VAProfile::Models::Telephone::HOME
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :extension, type: %i[string null]
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::VAProfile::Models::Telephone::WORK
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :extension, type: %i[string null]
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::VAProfile::Models::Telephone::TEMPORARY
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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
                  property :extension, type: %i[string null]
                  property :id, type: :integer, example: 123
                  property :is_international, type: :boolean
                  property :is_textable, type: :boolean
                  property :is_tty, type: :boolean
                  property :is_voicemailable, type: :boolean
                  property :phone_number, type: :string, example: '5551234'
                  property :phone_type, type: :string, example: ::VAProfile::Models::Telephone::FAX
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2018-04-21T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
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

                property :text_permission, type: :object do
                  property :id, type: :integer, example: 123
                  property :permission_type, type: :string, example: ::VAProfile::Models::Permission::TEXT
                  property :permission_value, type: :boolean, example: true
                  property :created_at,
                           type: :string,
                           format: 'date-time',
                           example: '2019-00-23T20:09:50Z'
                  property :effective_end_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2019-00-23T20:09:50Z'
                  property :effective_start_date,
                           type: %i[string null],
                           format: 'date-time',
                           example: '2019-00-23T20:09:50Z'
                  property :source_date,
                           type: :string,
                           format: 'date-time',
                           example: '2019-00-23T20:09:50Z'
                  property :updated_at,
                           type: :string,
                           format: 'date-time',
                           example: '2019-00-23T20:09:50Z'
                end
              end
            end
          end
        end
      end
    end
  end
end
