module ClaimsApi
  module Entities
    module V2
      class DisabilityClaimSubmittedEntity < ClaimsApi::Entities::V2::ClaimSubmittedEntity
        expose '@links', using: ClaimsApi::Entities::V2::LinkEntity do |instance, options|
          [
            { rel: 'Check status of claim',
              type: 'GET',
              url: "#{options[:base_url]}/services/claims/v2/claims/#{instance.id}" },
            { rel: 'Upload supporting documents',
              type: 'POST',
              url: "#{options[:base_url]}/services/claims/v2/forms/526/#{instance.id}/attachments" }
          ]
        end
      end
    end
  end
end
