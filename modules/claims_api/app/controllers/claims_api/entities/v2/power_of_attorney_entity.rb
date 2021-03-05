module ClaimsApi
  module Entities
    module V2
      class PowerOfAttorneyEntity < Grape::Entity
        expose :current_poa, as: :code, documentation: { type: String }
        expose :status, documentation: { type: String }
      end
    end
  end
end
