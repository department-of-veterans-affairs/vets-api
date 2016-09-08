# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      if education_benefits_claim.save
        render(json: education_benefits_claim)
      else
        render(json: education_benefits_claim.errors, status: :bad_request)
      end
    end

    private

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form).tap do |whitelisted|
        whitelisted[:form] = params[:education_benefits_claim][:form]
      end
    end
  end
end
