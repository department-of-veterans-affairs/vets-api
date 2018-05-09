# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Telephone
        include Swagger::Blocks

        swagger_schema :PostVet360Telephone do
          key :required, %i[phone_number area_code phone_type]
          property :phone_number,
                   type: :string,
                   example: '5551212',
                   minLength: 1,
                   maxLength: 14,
                   pattern: ::Vet360::Models::Telephone::VALID_PHONE_NUMBER_REGEX.inspect
          property :area_code,
                   type: :string,
                   example: '303',
                   minLength: 3,
                   maxLength: 3,
                   pattern: ::Vet360::Models::Telephone::VALID_AREA_CODE_REGEX.inspect
          property :extension,
                   type: :string,
                   example: '101',
                   maxLength: 10
          property :phone_type,
                   type: :string,
                   enum: ::Vet360::Models::Telephone::PHONE_TYPES,
                   example: ::Vet360::Models::Telephone::MOBILE
        end

        swagger_schema :PutVet360Telephone do
          key :required, %i[id phone_number area_code phone_type]
          property :id, type: :integer, example: 1
          property :phone_number,
                   type: :string,
                   example: '5551212',
                   minLength: 1,
                   maxLength: 14,
                   pattern: ::Vet360::Models::Telephone::VALID_PHONE_NUMBER_REGEX.inspect
          property :area_code,
                   type: :string,
                   example: '303',
                   minLength: 3,
                   maxLength: 3,
                   pattern: ::Vet360::Models::Telephone::VALID_AREA_CODE_REGEX.inspect
          property :extension,
                   type: :string,
                   example: '101',
                   maxLength: 10
          property :phone_type,
                   type: :string,
                   enum: ::Vet360::Models::Telephone::PHONE_TYPES,
                   example: ::Vet360::Models::Telephone::MOBILE
        end
      end
    end
  end
end
