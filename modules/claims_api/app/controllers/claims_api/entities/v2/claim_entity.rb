module ClaimsApi
  module Entities
    module V2
      class ClaimEntity < Grape::Entity
        expose :id, documentation: {
                      type: String,
                      example: '6dca620c-e737-4168-a9d1-5aac85fec915'
                    } do |instance, _options|
          valid_identifier(instance)
        end
        expose :self, documentation: {
                        type: String,
                        example: 'https://api.va.gov/services/claims/v2/claims/6dca620c-e737-4168-a9d1-5aac85fec915'
                      } do |instance, options|
          "#{options[:base_url]}/services/claims/v2/claims/#{valid_identifier(instance)}"
        end
        expose :status, documentation: {
                          type: String,
                          example: 'pending'
                        } do |instance, _options|
          if instance.respond_to?(:status)
            instance.status
          elsif instance.respond_to?(:list_data)
            instance.list_data['status'].downcase
          end
        end
        expose :attributes, documentation: { type: Hash, desc: 'Additional attributes' } do
          expose :evss_id, as: :vbmsClaimId, documentation: { type: Integer, example: 8347210 }
          expose :claimType, documentation: { type: String, example: 'Compensation' } do |instance, _options|
            if instance.respond_to?(:list_data)
              instance.list_data['status_type']
            end
          end
        end

        private

        def valid_identifier(instance)
          return instance.id if instance.respond_to?(:id)
          return nil unless instance.respond_to?(:evss_id)

          claim = ClaimsApi::AutoEstablishedClaim.find_by(evss_id: instance.evss_id)
          return claim.id if claim.present?

          instance.respond_to?(:evss_id) ? instance.evss_id : nil
        end
      end
    end
  end
end
