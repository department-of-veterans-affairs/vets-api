# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      unless claim.save
        validation_error = claim.errors.full_messages.join(', ')

        log_message_to_sentry(validation_error, :error, {}, validation: 'education_benefits_claim')

        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end

      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "ClaimID=#{claim.id} RPO=#{claim.region} Form=#{claim.form_type}"
      render(json: claim)
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
