# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def index
          bgs_claims = bgs_service.benefit_claims.find_claims_details_by_participant_id(
            participant_id: target_veteran.participant_id
          )
          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)
          merged_claims = BGSToLighthouseClaimsMapperService.process(bgs_claims: bgs_claims,
                                                                     lighthouse_claims: lighthouse_claims)

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(merged_claims)
        end

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end
      end
    end
  end
end
