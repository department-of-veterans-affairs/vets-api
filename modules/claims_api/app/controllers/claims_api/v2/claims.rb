module ClaimsApi
  module V2
    class Claims < ClaimsApi::V2::Base
      helpers do
        def claims_service
          ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
        end
      end

      before do
        permit_scopes %w[claim.read]
      end

      resource :claims do
        desc 'Return all claims.'
        get '/' do
          evss_claims = claims_service.all
          present evss_claims, with: ClaimsApi::Entities::V2::ClaimEntity
        end

        desc 'Return a claim.'
        params do
          requires :id, type: Integer, desc: 'Claim ID.'
        end
        route_param :id do
          get do
            claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
            claim = claims_service.update_from_remote(params[:id]) if claim.blank?

            present claim, with: ClaimsApi::Entities::V2::ClaimEntity
          end
        end
      end
    end
  end
end
