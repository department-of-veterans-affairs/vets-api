module ClaimsApi
  module Entities
    module V2
      class ClaimSubmittedEntity < Grape::Entity
        expose :id, documentation: { type: String }
        expose :self do |instance, _options|
          "#{options[:base_url]}/services/claims/v2/claims/#{instance.id}"
        end
        expose :status, documentation: { type: String }
      end
    end
  end
end
