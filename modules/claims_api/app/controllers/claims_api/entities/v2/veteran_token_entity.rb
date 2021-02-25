module ClaimsApi
  module Entities
    module V2
      class VeteranTokenEntity < Grape::Entity
        expose :id, documentation: { type: String }
      end
    end
  end
end
