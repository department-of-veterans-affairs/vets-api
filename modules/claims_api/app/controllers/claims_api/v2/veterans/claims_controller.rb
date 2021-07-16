# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :verify_target_user

        def index
          service_params    = { participant_id: target_veteran.participant_id }
          bgs_claims        = bgs_service.benefit_claims.find_claims_details_by_participant_id(service_params)

          query_params      = { veteran_icn: target_veteran.mpi.icn }
          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(query_params)

          mapper_params     = { bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims }
          claims            = BGSToLighthouseClaimsMapperService.process(mapper_params)

          render json: claims
        end

        def show
          bgs_claim = bgs_service.benefit_claims.find_claim_details_by_claim_id(claim_id: params[:id])
          claim_details = bgs_claim.dig(:bnft_claim_detail)

          if claim_details.present?
            claim = { id: claim_details[:bnft_claim_id], type: claim_details[:bnft_claim_type_nm] }
            render json: claim
          else
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end
        end

        private

        def verify_target_user
          raise ::Common::Exceptions::Forbidden unless user_is_target_veteran? || user_is_representative?
        end

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end
      end
    end
  end
end
