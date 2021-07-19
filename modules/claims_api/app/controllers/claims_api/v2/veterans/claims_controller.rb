# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def index
          service           = bgs_service(veteran_participant_id: target_veteran.participant_id)
          service_params    = { participant_id: target_veteran.participant_id }
          bgs_claims        = service.benefit_claims.find_claims_details_by_participant_id(service_params)

          query_params      = { veteran_icn: target_veteran.mpi.icn }
          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(query_params)

          mapper_params     = { bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims }
          claims            = BGSToLighthouseClaimsMapperService.process(mapper_params)

          render json: claims
        end

        private

        def bgs_service(veteran_participant_id:)
          BGS::Services.new(external_uid: veteran_participant_id, external_key: veteran_participant_id)
        end
      end
    end
  end
end
