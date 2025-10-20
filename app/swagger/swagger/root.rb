# frozen_string_literal: true

module Swagger
  class Root
    include Swagger::Blocks

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, 'v0'
        key :title, 'vets-api'
      end
      key :basePath, '/'
      key :consumes, ['application/json']
      key :produces, ['application/json']
    end
  end
end
