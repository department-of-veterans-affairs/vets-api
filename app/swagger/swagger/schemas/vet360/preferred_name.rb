# frozen_string_literal: true

require 'va_profile/models/preferred_name'

module Swagger
  module Schemas
    module Vet360
      class PreferredName
        include Swagger::Blocks

        swagger_schema :PutPreferredName do
          key :required, %i[text]
          property :text,
                   type: :string,
                   example: 'Pat',
                   minLength: 1,
                   maxLength: 25,
                   description: 'Describes preferred name text.'
        end

        swagger_schema :PreferredName do
          key :required, [:data]

          property :data, type: :object do
            key :required, [:attributes]
            property :id, type: :string
            property :type, type: :string
            property :attributes, type: :object do
              property :text, type: :string, example: 'Pat'
              property :source_system_user, type: :string, example: '123498767V234859'
              property :source_date, type: :string, format: 'date-time', example: '2022-04-08T15:09:23.000Z'
            end
          end
        end
      end
    end
  end
end
