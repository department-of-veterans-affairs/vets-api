# frozen_string_literal: true

module V0
  class VeteranReadinessEmploymentClaimsController < ClaimsBaseController
    def create
      load_user
      claim = SavedClaim::VeteranReadinessEmploymentClaim.new(form: filtered_params[:form])
      claim.add_claimant_info(current_user)

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"

      claim.send_to_central_mail! if current_user && current_user.participant_id.blank?
      claim.send_to_vre(current_user)
      clear_saved_form(claim.form_id)
      render json: claim
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
