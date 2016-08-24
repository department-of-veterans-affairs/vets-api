module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      render(json: education_benefits_claim.save ? education_benefits_claim : education_benefits_claim.errors)
    end

    private

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form).tap do |whitelisted|
        whitelisted[:form] = params[:education_benefits_claim][:form]
      end
    end
  end
end
