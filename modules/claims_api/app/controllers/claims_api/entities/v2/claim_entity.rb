module ClaimsApi
  module Entities
    module V2
      class ClaimEntity < Grape::Entity
        expose :id, documentation: { type: 'String' } do |instance, _options|
          return instance.id if instance.respond_to?(:id)
          return nil unless instance.respond_to?(:evss_id)

          claim = ClaimsApi::AutoEstablishedClaim.find_by(evss_id: instance.evss_id)
          return claim.id if claim.present?

          instance.respond_to?(:evss_id) ? instance.evss_id : nil
        end
        expose :self do |instance, _options|
          "http://localhost:3000/services/claims/v2/claims/#{instance.evss_id}"
        end
        expose :type, documentation: { type: 'String' } do |_instance, _options|
          'evss_claims'
        end
        expose :attributes, documentation: { type: Hash, desc: 'Additional attributes' } do
          expose :evss_id, as: :gov_id, documentation: { type: Integer }
          expose :status, documentation: { type: 'String' } do |instance, _options|
            instance.list_data['status']
          end
        end
      end
    end
  end
end
