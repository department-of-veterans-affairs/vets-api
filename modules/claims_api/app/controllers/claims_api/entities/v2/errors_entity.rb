module ClaimsApi
  module Entities
    module V2
      class ErrorsEntity < Grape::Entity
        expose :errors, documentation: { type: Array } do
          expose :title, documentation: { type: String }
          expose :detail, documentation: { type: String }
          expose :code, documentation: { type: String }
          expose :status, documentation: { type: String }
        end
      end
    end
  end
end
