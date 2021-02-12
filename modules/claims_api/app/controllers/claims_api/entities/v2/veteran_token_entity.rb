module ClaimsApi
  module Entities
    module V2
      class VeteranTokenEntity < Grape::Entity
        expose :token, documentation: { type: String }
      end
    end
  end
end
