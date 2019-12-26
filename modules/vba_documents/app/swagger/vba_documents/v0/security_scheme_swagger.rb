# frozen_string_literal: true

module VbaDocuments
  module V0
    class SecuritySchemeSwagger
      include Swagger::Blocks
      swagger_component do
        security_scheme :apikey do
          key :type, :apiKey
          key :name, :apikey
          key :in, :header
        end
      end
    end
  end
end
