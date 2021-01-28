module ClaimsApi
  module Entities
    module V2
      class ErrorEntity < Grape::Entity
        expose :title, documentation: { type: String }
        expose :detail, documentation: { type: String }
        expose :code, documentation: { type: String }
        expose :status, documentation: { type: String }
      end
    end
  end
end
