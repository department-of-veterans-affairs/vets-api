# frozen_string_literal: true

module Swagger
  module Requests
    class VirtualAgentTokenNlu
      include Swagger::Blocks

      swagger_path '/v0/virtual_agent_token_nlu' do
        operation :post do
          key :description, 'Gets a webchat token for the NLU version of PVA'
          key :operationId, 'getToken'
          key :tags, %w[virtual_agent]

          response 200 do
            key :description, 'Webchat Token'
            schema do
              key :$ref, :VirtualAgentWebchatToken
            end
          end
        end
      end
    end
  end
end
