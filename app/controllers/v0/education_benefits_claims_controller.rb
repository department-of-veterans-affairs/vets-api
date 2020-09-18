# frozen_string_literal: true

module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      claim = SavedClaim::EducationBenefits.form_class(form_type).new(education_benefits_claim_params)

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end

      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "ClaimID=#{claim.id} RPO=#{claim.education_benefits_claim.region} Form=#{form_type}"
      load_user
      claim.after_submit(@current_user)
      clear_saved_form(claim.in_progress_form_id)
      render(json: claim.education_benefits_claim)
    end

    private

    def form_type
      params[:form_type] || '1990'
    end

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form)
    end

    def stats_key
      "api.education_benefits_claim.22#{form_type}"
    end
  end
end
