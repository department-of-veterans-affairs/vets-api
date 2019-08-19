# frozen_string_literal: true

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
                   pattern: ::Vet360::Models::Telephone::VALID_AREA_CODE_REGEX.inspect
          property :country_code,
                   type: :string,
                   enum: ['1'],
                   example: '1'
          # property :created_at,
          #          type: :string,
          #          format: 'date-time',
          #          example: '2018-04-21T20:09:50Z'
          property :effective_end_date,
                   type: %i[string null],
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z'
          property :effective_start_date,
                   type: %i[string null],
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z'
          property :extension,
                   type: :string,
                   example: '101',
                   maxLength: 10
          property :is_international,
                   type: :boolean,
                   example: false
          property :is_textable,
                   type: :boolean,
                   example: true
          property :is_text_permitted,
                   type: :boolean,
                   example: true
          property :is_tty, 
                   type: :boolean,
                   example: true
          property :is_voicemailable, 
                   type: :boolean,
                   example: true
          property :phone_number,
                   type: :string,
                   example: '5551212',
                   minLength: 1,
                   maxLength: 14,
                   pattern: ::Vet360::Models::Telephone::VALID_PHONE_NUMBER_REGEX.inspect
          property :phone_type,
                   type: :string,
                   enum: ::Vet360::Models::Telephone::PHONE_TYPES,
                   example: ::Vet360::Models::Telephone::MOBILE
          property :source_date,
                   type: :string,
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z'
          # property :updated_at,
          #          type: :string,
          #          format: 'date-time',
          #          example: '2018-04-21T20:09:50Z'
          property :vet360_id, 
                   type: :integer, 
                   example: 1
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
                   pattern: ::Vet360::Models::Telephone::VALID_AREA_CODE_REGEX.inspect
          property :country_code,
                   type: :string,
                   enum: ['1'],
                   example: '1'
          # property :created_at,
          #          type: :string,
          #          format: 'date-time',
          #          example: '2018-04-21T20:09:50Z'
          property :effective_end_date,
                   type: %i[string null],
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z'
          property :effective_start_date,
                   type: %i[string null],
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z'
          property :extension,
                   type: :string,
                   example: '101',
                   maxLength: 10
          property :is_international,
                   type: :boolean,
                   example: false
          property :is_textable,
                   type: :boolean,
                   example: true
          property :is_text_permitted,
                   type: :boolean,
                   example: true
          property :is_tty, 
                   type: :boolean,
                   example: true
          property :is_voicemailable, 
                   type: :boolean,
                   example: true
          property :phone_number,
                   type: :string,
                   example: '5551212',
                   minLength: 1,
                   maxLength: 14,
                   pattern: ::Vet360::Models::Telephone::VALID_PHONE_NUMBER_REGEX.inspect
          property :phone_type,
                   type: :string,
                   enum: ::Vet360::Models::Telephone::PHONE_TYPES,
                   example: ::Vet360::Models::Telephone::MOBILE
          property :source_date,
                   type: :string,
                   format: 'date-time',
                   example: '2018-04-21T20:09:50Z'
          # property :updated_at,
          #          type: :string,
          #          format: 'date-time',
          #          example: '2018-04-21T20:09:50Z'
          property :vet360_id, 
                   type: :integer, 
                   example: 1
        end
      end
    end
  end
end
