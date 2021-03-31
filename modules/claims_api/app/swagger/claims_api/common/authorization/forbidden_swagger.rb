# frozen_string_literal: true

module ClaimsApi
  module Common
    module Authorization
      class ForbiddenSwagger
        include Swagger::Blocks

        swagger_component do
          schema :ForbiddenModel do
            property :title do
              key :type, :string
              key :example, 'Forbidden'
              key :description, 'HTTP error title'
            end

            property :detail do
              key :type, :string
              key :example, 'Action is forbidden'
              key :description, 'HTTP error detail'
            end

            property :code do
              key :type, :string
              key :example, '403'
              key :description, 'HTTP error code'
            end

            property :status do
              key :type, :string
              key :example, '403'
              key :description, 'HTTP error code'
            end
          end
        end
      end
    end
  end
end
