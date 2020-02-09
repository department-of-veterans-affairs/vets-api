# frozen_string_literal: true

module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      validate_session

      claim = service.submit_claim!(current_user, claim_params)

      render json: claim, serializer: SavedClaimSerializer
    end

    private

    def service
      CaregiversAssistanceClaimsService.new
    end

    def claim_params
      params.require(:caregivers_assistance_claim).permit(:form)
    end
  end
end
