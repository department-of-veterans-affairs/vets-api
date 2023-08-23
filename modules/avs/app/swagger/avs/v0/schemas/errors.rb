# frozen_string_literal: true

module Avs
  class V0::Schemas::Errors
    include Swagger::Blocks

    swagger_schema :Errors do
      key :required, [:errors]

      property :errors do
        key :type, :array
        items do
          key :$ref, :Error
        end
      end
    end

    swagger_schema :Error do
      property :title, type: :string
      property :detail, type: :string
      property :code, type: :string
      property :status, type: :string
    end
  end
end
