# frozen_string_literal: true

module VBADocuments
  module V2
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
