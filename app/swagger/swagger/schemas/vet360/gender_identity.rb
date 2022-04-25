# frozen_string_literal: true

require 'va_profile/models/gender_identity'

module Swagger
  module Schemas
    module Vet360
      class GenderIdentity
        include Swagger::Blocks

        swagger_schema :PutGenderIdentity do
          key :required, %i[code]
          property :code,
                   type: :string,
                   enum: ::VAProfile::Models::GenderIdentity::CODES,
                   example: 'F',
                   description: 'Describes gender identity code.'
        end

        swagger_schema :GenderIdentity do
          property :code, type: :string, example: 'F'
          property :name, type: :string, example: 'Female'
          property :source_system_user, type: :string, example: '123498767V234859'
          property :source_date, type: :string, format: 'date-time', example: '2022-04-08T15:09:23.000Z'
        end
      end
    end
  end
end
