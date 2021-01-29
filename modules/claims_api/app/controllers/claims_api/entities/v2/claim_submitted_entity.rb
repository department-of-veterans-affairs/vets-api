module ClaimsApi
  module Entities
    module V2
      class ClaimSubmittedEntity < Grape::Entity
        expose :id, documentation: { type: String, example: '6dca620c-e737-4168-a9d1-5aac85fec915' }
        expose :self, documentation: {
                        type: String,
                        example: 'https://api.va.gov/services/claims/v2/claims/6dca620c-e737-4168-a9d1-5aac85fec915'
                      } do |instance, options|
          "#{options[:base_url]}/services/claims/v2/claims/#{instance.id}"
        end
        expose :status, documentation: { type: String, example: 'pending' }
      end
    end
  end
end
