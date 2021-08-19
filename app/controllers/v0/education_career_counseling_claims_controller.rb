# frozen_string_literal: true

module V0
  class EducationCareerCounselingClaimsController < ClaimsBaseController
    def create
      load_user
      claim = SavedClaim::EducationCareerCounselingClaim.new(form: filtered_params[:form])

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.send_to_central_mail!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)
      render(json: claim)
    end

    private

    def short_name
      'education_career_counseling_claim'
    end
  end
end
