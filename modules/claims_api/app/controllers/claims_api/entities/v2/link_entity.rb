module ClaimsApi
  module Entities
    module V2
      class LinkEntity < Grape::Entity
        expose :rel, documentation: { type: String }
        expose :type, documentation: { type: String  }
        expose :url, documentation: { type: String }
      end
    end
  end
end
