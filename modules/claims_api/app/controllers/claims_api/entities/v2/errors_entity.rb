module ClaimsApi
  module Entities
    module V2
      class ErrorsEntity < Grape::Entity
        expose :errors, documentation: { type: Array } do
          expose :title, documentation: { type: String, example: 'Something bad happened.' }
          expose :detail, documentation: { type: String, example: 'Details of what exactly went wrong.' }
          expose :code, documentation: { type: String, example: '500'  }
          expose :status, documentation: { type: String, example: '500' }
        end
      end
    end
  end
end
