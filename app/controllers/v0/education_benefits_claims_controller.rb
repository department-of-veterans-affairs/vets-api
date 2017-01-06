# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    STATSD_SUBMISSION_KEY = 'api.education_benefits_claim.221990.'

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      unless education_benefits_claim.save
        validation_error = education_benefits_claim.errors.full_messages.join(', ')

        Raven.capture_message(validation_error, tags: { validation: 'education_benefits_claim' })

        logger.error(validation_error)

        StatsD.increment("#{STATSD_SUBMISSION_KEY}failure")
        raise Common::Exceptions::ValidationErrors, education_benefits_claim
      end

      StatsD.increment("#{STATSD_SUBMISSION_KEY}success")

      render(json: education_benefits_claim)
    end

    private

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form)
    end
  end
end
