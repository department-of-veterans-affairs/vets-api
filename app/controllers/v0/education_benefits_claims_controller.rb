# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      unless education_benefits_claim.save
        validation_error = education_benefits_claim.errors.full_messages.join(', ')

        Raven.tags_context(validation: 'education_benefits_claim')
        Raven.capture_exception(validation_error)

        logger.error(validation_error)
        raise Common::Exceptions::ValidationErrors, education_benefits_claim
      end

      render(json: education_benefits_claim)
    end

    private

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form)
    end
  end
end
