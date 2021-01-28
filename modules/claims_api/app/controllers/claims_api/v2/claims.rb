module ClaimsApi
  module V2
    class Claims < ClaimsApi::V2::Base
      version 'v2'

      helpers do
        def claims_service
          ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
        end
      end

      before do
        authenticate
        permit_scopes %w[claim.read]
      end

      resource :claims do
        desc 'Return all claims.' do
          success ClaimsApi::Entities::V2::ClaimEntity
          failure [[401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity']]
        end
        get '/' do
          non_established_claims = ClaimsApi::AutoEstablishedClaim.where(source: source_name)
                                                                  .where('evss_id is null')
          established_claims = ClaimsApi::AutoEstablishedClaim.where(source: source_name)
                                                              .where('evss_id is not null')
          evss_claims = claims_service.all

          merged_claims = non_established_claims.to_a
          evss_claims.each do |evss_claim|
            our_claim = established_claims.find do |established_claim|
                          established_claim.evss_id.to_i == evss_claim.evss_id
                        end
            our_claim.present? ? merged_claims.push(our_claim) : merged_claims.push(evss_claim)
          end

          present merged_claims, with: ClaimsApi::Entities::V2::ClaimEntity, base_url: request.base_url
        end

        desc 'Return a claim.' do
          success ClaimsApi::Entities::V2::ClaimEntity
          failure [[401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity']]
        end
        params do
          requires :id, type: String, desc: 'Claim ID.'
        end
        route_param :id do
          get do
            claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
            claim = claims_service.update_from_remote(params[:id]) if claim.blank?
            # TODO: figure out all these statuses
            #   seems statuses are different based on whether we processed the claim or not

            present claim, with: ClaimsApi::Entities::V2::ClaimEntity, base_url: request.base_url
          end
        end
      end
    end
  end
end
