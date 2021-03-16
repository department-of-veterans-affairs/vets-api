module ClaimsApi
  module V2
    class PowerOfAttorneys < ClaimsApi::V2::Base
      version 'v2'
      helpers do
        def bgs_service
          BGS::Services.new(
            external_uid: target_veteran.participant_id,
            external_key: target_veteran.participant_id
          )
        end
      end

      before do
        authenticate
        permit_scopes %w[claim.read]
      end

      resource 'veterans/:veteranId' do
        resource 'power-of-attorneys' do
          desc 'Return all power of attorneys historically associated with Veteran.' do
            detail <<~X
              Returns pending power of attorneys submitted through this API as well as any established power of
              attorneys submitted from other sources.
            X
            # success ClaimsApi::Entities::V2::ClaimEntity
            failure [[401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity']]
            tags ['Claims']
            security [{ bearer_token: [] }]
          end
          params do
            requires :token, type: String
          end
          get '/' do
            pending_poas = ClaimsApi::PowerOfAttorney.where(status: ClaimsApi::PowerOfAttorney::PENDING).each do |poa|
              poa.status = 'active'
            end
            historical_poas = bgs_service.org.find_poas_by_ptcpnt_id(target_veteran.participant_id) || []
            merged_poas = pending_poas + historical_poas

            present merged_poas, with: ClaimsApi::Entities::V2::PowerOfAttorneyEntity, base_url: request.base_url
          end
        end
      end
    end
  end
end
