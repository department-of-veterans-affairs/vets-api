# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        def index
          raise ::Common::Exceptions::Forbidden unless user_is_target_veteran? || user_is_representative?

          service   = bgs_service(veteran_participant_id: target_veteran.participant_id)
          params    = { participant_id: target_veteran.participant_id }
          response  = service.benefit_claims.find_claims_details_by_participant_id(params)
          claims    = transform_response(response: response)

          render json: claims
        end

        private

        def bgs_service(veteran_participant_id:)
          BGS::Services.new(external_uid: veteran_participant_id, external_key: veteran_participant_id)
        end

        def transform_response(response:)
          return [] unless response.key?(:bnft_claim_detail)

          response[:bnft_claim_detail].map do |claim|
            {
              id: claim[:bnft_claim_id],
              type: claim[:bnft_claim_type_nm]
            }
          end
        end
      end
    end
  end
end
