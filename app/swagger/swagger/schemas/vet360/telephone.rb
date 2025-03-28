# frozen_string_literal: true

require 'va_profile/models/telephone'

module Swagger
  module Schemas
    module Vet360
      class Telephone
        include Swagger::Blocks

        swagger_schema :PostVet360Telephone do
          key :required, %i[phone_number area_code phone_type is_international country_code]
          property :area_code,
                   type: :string,
                   example: '303',
                   minLength: 3,
                   maxLength: 3,
                   pattern: ::VAProfile::Models::Telephone::VALID_AREA_CODE_REGEX.inspect,
                   description: 'The three-digit code that begins a North American (the U.S., Canada and Mexico) phone
                   number.'
          property :country_code,
                   type: :string,
                   enum: ['1'],
                   example: '1',
                   description: 'First two to four digits of a non- North American phone number that routes the call to
                   country of that phone number.'
          property :extension,
                   type: :string,
                   example: '101',
                   maxLength: 6,
                   description: 'One-or-more digit number that must be dialed after reaching a main number, typically at
                   an establishment, in order to reach a specific party.'
          property :is_international,
                   type: :boolean,
                   example: false
          property :is_textable,
                   type: :boolean,
                   example: true,
                   description: 'Indicates phone number is capable of receiving text messages.'
          property :is_text_permitted,
                   type: :boolean,
                   example: true,
                   description: 'Indicates person has granted permission to receive text messages to phone number.'
          property :is_voicemailable,
                   type: :boolean,
                   example: true,
                   description: 'Indicates person has granted consent to record a voice mail message on a phone number.'
          property :phone_number,
                   type: :string,
                   example: '5551212',
                   minLength: 1,
                   maxLength: 14,
                   pattern: ::VAProfile::Models::Telephone::VALID_PHONE_NUMBER_REGEX.inspect,
                   description: 'Number that follows an area code for a North American phone number, or a country code
                   for a non-North American phone number.'
          property :phone_type,
                   type: :string,
                   enum: ::VAProfile::Models::Telephone::PHONE_TYPES,
                   example: ::VAProfile::Models::Telephone::MOBILE,
                   description: 'Describes specific type of phone number.'
          property :source_date,
                   type: :string,
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z',
                   description: 'The date the source system received the last update to this bio.'
          property :vet360_id,
                   type: :integer,
                   example: 1,
                   description: 'Unique Identifier of individual within VET360. Created by VET360 after it is validated
                   and accepted. May be considered PII.'
        end

        swagger_schema :PutVet360Telephone do
          key :required, %i[id phone_number area_code phone_type is_international country_code]
          property :id,
                   type: :integer,
                   example: 1
          property :area_code,
                   type: :string,
                   example: '303',
                   minLength: 3,
                   maxLength: 3,
                   pattern: ::VAProfile::Models::Telephone::VALID_AREA_CODE_REGEX.inspect,
                   description: 'The three-digit code that begins a North American (the U.S., Canada and Mexico) phone
                   number.'
          property :country_code,
                   type: :string,
                   enum: ['1'],
                   example: '1',
                   description: 'First two to four digits of a non- North American phone number that routes the call to
                   country of that phone number.'
          property :extension,
                   type: :string,
                   example: '101',
                   maxLength: 10,
                   description: 'One-or-more digit number that must be dialed after reaching a main number, typically at
                   an establishment, in order to reach a specific party.'
          property :is_international,
                   type: :boolean,
                   example: false
          property :is_textable,
                   type: :boolean,
                   example: true,
                   description: 'Indicates phone number is capable of receiving text messages.'
          property :is_text_permitted,
                   type: :boolean,
                   example: true,
                   description: 'Indicates person has granted permission to receive text messages to phone number.'
          property :is_voicemailable,
                   type: :boolean,
                   example: true,
                   description: 'Indicates person has granted consent to record a voice mail message on a phone number.'
          property :phone_number,
                   type: :string,
                   example: '5551212',
                   minLength: 1,
                   maxLength: 14,
                   pattern: ::VAProfile::Models::Telephone::VALID_PHONE_NUMBER_REGEX.inspect,
                   description: 'Number that follows an area code for a North American phone number, or a country code
                   for a non-North American phone number.'
          property :phone_type,
                   type: :string,
                   enum: ::VAProfile::Models::Telephone::PHONE_TYPES,
                   example: ::VAProfile::Models::Telephone::MOBILE,
                   description: 'Describes specific type of phone number.'
          property :source_date,
                   type: :string,
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z',
                   description: 'The date the source system received the last update to this bio.'
          property :vet360_id,
                   type: :integer,
                   example: 1,
                   description: 'Unique Identifier of individual within VET360. Created by VET360 after it is validated
                   and accepted. May be considered PII.'
        end
      end
    end
  end
end
