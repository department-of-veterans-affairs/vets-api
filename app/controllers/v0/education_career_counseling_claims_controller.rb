module V0
  class EducationCareerCounselingClaimsController < ApplicationController
    def create
      claim = career_counseling_claim
      claim.add_veteran_info(current_user) if current_user

      unless claim.save!
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.process_attachments!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      # clear_saved_form(claim.form_id)
      render(json: claim)
    end

    private

    def career_counseling_params
      params.require(:education_career_counseling_claim).permit(
        :status,
        :claimant_phone_number,
        :claimant_email_address,
        claimant_address: {}
      )
    end

    def career_counseling_claim
      SavedClaim::EducationCareerCounselingClaim.new(
        form: career_counseling_params.to_json
      )
    end

    def stats_key
      'api.education_career_counseling'
    end
  end
end