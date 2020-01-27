# frozen_string_literal: true

module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    skip_before_action(:authenticate)

    # TODO: soft-launch docs: https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/backend/soft-launch-strategies.md
    def create
      validate_session

      claim = service.submit_application!(current_user, caregivers_assistance_application_params)

      # TODO: what do I render here?
      # TODO: serialize https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/backend/vets-api/response-serialization.md
      render json: claim, serializer: SavedClaimSerializer, status: :created
    end

    private

    def service
      CaregiversAssistanceClaimsService.new
    end

    def caregivers_assistance_application_params
      params.require(:caregivers_assistance_claim).permit(:form)
    end
  end
end
