# frozen_string_literal: true

module ClaimsApi
  module V1
    class SecuritySchemeSwagger
      include Swagger::Blocks
      swagger_component do
        security_scheme :bearer do
          key :type, :http
          key :name, :token
          key :in, :header
        end
      end
    end
  end
end
