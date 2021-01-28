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
        end
        get '/' do
          our_claims = ClaimsApi::AutoEstablishedClaim.where(source: "#{source_name}")
          evss_claims = claims_service.all
          # TODO: merge our established claims with evss's

          present our_claims + evss_claims, with: ClaimsApi::Entities::V2::ClaimEntity, base_url: request.base_url
        end

        desc 'Return a claim.' do
          success ClaimsApi::Entities::V2::ClaimEntity
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
