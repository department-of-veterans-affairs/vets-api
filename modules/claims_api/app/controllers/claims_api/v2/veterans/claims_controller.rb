# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        def index
          vet = ClaimsApi::Veteran.new(
            mhv_icn: params[:veteranId],
            loa: @current_user.loa
          )
          vet.mpi

          service = BGS::Services.new(
            external_uid: vet.participant_id,
            external_key: vet.participant_id
          )

          response = service.benefit_claims.find_claims_details_by_participant_id(participant_id: vet.participant_id)

          render json: response
        end
      end
    end
  end
end
