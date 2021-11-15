# frozen_string_literal: true

module V0
  class VeteranReadinessEmploymentClaimsController < ClaimsBaseController
    before_action :authenticate

    def create
      load_user
      claim = SavedClaim::VeteranReadinessEmploymentClaim.new(form: filtered_params[:form])

      if claim.save
        VRE::Submit1900Job.perform_async(claim.id, current_user.uuid)
        Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
        clear_saved_form(claim.form_id)
        render json: claim
      else
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end
    end

    private

    def filtered_params
      params.require(:veteran_readiness_employment_claim).permit(:form)
    end

    def short_name
      'veteran_readiness_employment_claim'
    end
  end
end
