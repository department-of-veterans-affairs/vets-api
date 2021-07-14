# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        def index
          raise ::Common::Exceptions::Forbidden unless user_is_target_veteran? || user_is_representative?

          service           = bgs_service(veteran_participant_id: target_veteran.participant_id)
          params            = { participant_id: target_veteran.participant_id }
          bgs_claims        = service.benefit_claims.find_claims_details_by_participant_id(params)
          internal_claims   = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)
          claims            = map_claims(bgs_claims: bgs_claims, internal_claims: internal_claims)

          render json: claims
        end

        private

        def bgs_service(veteran_participant_id:)
          BGS::Services.new(external_uid: veteran_participant_id, external_key: veteran_participant_id)
        end

        def map_claims(bgs_claims:, internal_claims:)
          return [] unless bgs_claims.key?(:bnft_claim_detail) || internal_claims.present?

          mapped_claims = bgs_claims[:bnft_claim_detail].map do |external_claim|
            match = internal_claims.find { |internal_claim| internal_claim.evss_id == external_claim[:bnft_claim_id] }

            if match
              internal_claims.delete(match)
              { id: match.id, type: external_claim[:bnft_claim_type_nm] }
            else
              { id: external_claim[:bnft_claim_id], type: external_claim[:bnft_claim_type_nm] }
            end
          end

          if internal_claims.present?
            internal_claims.each do |remaining_claim|
              mapped_claims.push({ id: remaining_claim.id, type: remaining_claim.claim_type })
            end
          end

          mapped_claims
        end
      end
    end
  end
end
