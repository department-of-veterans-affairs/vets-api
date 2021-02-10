module ClaimsApi
  module Entities
    module V2
      class ClaimSubmittedEntity < Grape::Entity
        expose :id, documentation: { type: String, example: '6dca620c-e737-4168-a9d1-5aac85fec915' }
        expose :status, documentation: { type: String, example: 'pending' }
        expose '@links', using: ClaimsApi::Entities::V2::LinkEntity do |instance, options|
          [
            { rel: 'Check status of claim',
              type: 'GET',
              url: "#{options[:base_url]}/services/claims/v2/claims/#{instance.id}" }
          ]
        end
      end
    end
  end
end
