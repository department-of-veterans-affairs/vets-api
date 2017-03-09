# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      unless education_benefits_claim.save
        validation_error = education_benefits_claim.errors.full_messages.join(', ')

        log_message_to_sentry(validation_error, :error, {}, { validation: 'education_benefits_claim' })

        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, education_benefits_claim
      end

      StatsD.increment("#{stats_key}.success")

      render(json: education_benefits_claim)
    end

    private

    def education_benefits_claim_params
      allowed_params = params.require(:education_benefits_claim).permit(:form)
      form_type = params[:form_type]
      allowed_params[:form_type] = form_type if form_type.present?

      allowed_params
    end

    def stats_key
      form = education_benefits_claim_params[:form_type] || '1990'
      "api.education_benefits_claim.22#{form}"
    end
  end
end
