# frozen_string_literal: true

module Swagger
  module Schemas
    class VirtualAgentWebchatToken
      include Swagger::Blocks

      swagger_schema :VirtualAgentWebchatToken do
        property :token,
                 type: :string
      end
    end
  end
end
