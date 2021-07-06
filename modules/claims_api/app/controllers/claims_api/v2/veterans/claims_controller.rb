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

          response = service.ClaimsService.read_available_claims(params[:veteranId])

          render json: { message: response }
        end
      end
    end
  end
end
