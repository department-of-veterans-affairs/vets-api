# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Telephone
        include Swagger::Blocks

        swagger_schema :PostVet360Telephone do
          key :required, %i[phone_number area_code phone_type]
          property :phone_number, type: :string, example: '5551212'
          property :area_code, type: :string, example: '303'
          property :extension, type: :string, example: '101'
          property :phone_type, type: :string, enum: %w[
            MOBILE
            HOME
            WORK
            FAX
            TEMPORARY
          ], example: 'MOBILE'
        end

        swagger_schema :PutVet360Telephone do
          key :required, %i[id phone_number area_code phone_type]
          property :id, type: :integer, example: 1
          property :phone_number, type: :string, example: '5551212'
          property :area_code, type: :string, example: '303'
          property :extension, type: :string, example: '101'
          property :phone_type, type: :string, enum: %w[
            MOBILE
            HOME
            WORK
            FAX
            TEMPORARY
          ], example: 'MOBILE'
        end
      end
    end
  end
end
