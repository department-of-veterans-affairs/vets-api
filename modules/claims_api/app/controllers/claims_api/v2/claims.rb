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

      resource 'veterans/:token' do
        resource :claims do
          desc 'Return all claims associated with Veteran.' do
            detail <<~X
              Returns pending claims submitted through this API as well as any established claims submitted
              from other sources.
            X
            success ClaimsApi::Entities::V2::ClaimEntity
            failure [[401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity']]
            tags ['Claims']
            security [{ bearer_token: [] }]
          end
          params do
            requires :token, type: String
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

          desc 'Return a claim for a Veteran by id.' do
            detail <<~X
              Accepts this API's uuid claim identifier to search claims submitted through this API.
              This endpoint also accepts a VBMS id to search for an established claim from any source.
            X
            success ClaimsApi::Entities::V2::ClaimEntity
            failure [[401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity']]
            tags ['Claims']
            security [{ bearer_token: [] }]
          end
          params do
            requires :token, type: String
            requires :id, type: String, desc: 'Unique claim identifier. Accepts either uuid or VBMS id.'
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
end
