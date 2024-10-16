# frozen_string_literal: true

module V0
  class EducationCareerCounselingClaimsController < ClaimsBaseController
    service_tag 'career-guidance-application'

    def create
      claim = SavedClaim::EducationCareerCounselingClaim.new(form: filtered_params[:form])

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Sentry.set_tags(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      Lighthouse::SubmitCareerCounselingJob.perform_async(claim.id, @current_user&.uuid)

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)
      render json: SavedClaimSerializer.new(claim)
    end

    private

    def short_name
      'education_career_counseling_claim'
    end
  end
end
