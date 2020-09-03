# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Permission
        include Swagger::Blocks

        swagger_schema :PostVet360Permission do
          key :required, %i[permission_type permission_value]
          property :permission_type,
                   type: :string,
                   enum: ::Vet360::Models::Permission::PERMISSION_TYPES,
                   example: ::Vet360::Models::Permission::TEXT,
                   description: 'Describes specific type of permission.'
          property :permission_value,
                   type: :boolean,
                   example: true,
                   description: 'Designates if Permission is granted.'
          property :source_date,
                   type: :string,
                   format: 'date-time',
                   example: '2019-00-23T20:09:50Z',
                   description: 'The date the source system received the last update to this bio.'
          property :vet360_id,
                   type: :integer,
                   example: 1,
                   description: 'Unique Identifier of individual within VET360. Created by VET360 after it is validated
                   and accepted. May be considered PII.'
        end

        swagger_schema :PutVet360Permission do
          key :required, %i[id permission_type permission_value]
          property :id,
                   type: :integer,
                   example: 1
          property :permission_type,
                   type: :string,
                   enum: ::Vet360::Models::Permission::PERMISSION_TYPES,
                   example: ::Vet360::Models::Permission::TEXT,
                   description: 'Describes specific type of permission.'
          property :permission_value,
                   type: :boolean,
                   example: true,
                   description: 'Designates if Permission is granted.'
          property :source_date,
                   type: :string,
                   format: 'date-time',
                   example: '2019-00-23T20:09:50Z',
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
