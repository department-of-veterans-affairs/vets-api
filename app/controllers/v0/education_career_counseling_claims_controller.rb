module V0
  class EducationCareerCounselingClaimsController < ApplicationController
    def create
      claim = SavedClaim::EducationCareerCounselingClaim.new(form: career_counseling_params.to_json)
      binding.pry
      unless claim.save!
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end
      binding.pry
      # claim.submit!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      # clear_saved_form(claim.form_id)
      render(json: claim)
    end

    # {
    #   "status"=>"isVeteran",
    #   "claimant_address"=>{
    #     "country_name"=>"USA",
    #     "address_line1"=>"9417 Princess Palm",
    #     "city"=>"Tampa",
    #     "state_code"=>"FL",
    #     "zip_code"=>"33928"
    #   },
    #   "claimant_phone_number"=>"5555555555",
    #   "claimant_email_address"=>"cohnjesse@gmail.xom",
    #   "claimant_confirm_email_address"=>"cohnjesse@gmail.xom",
    #   "format"=>"json",
    #   "controller"=>"v0/education_career_counseling_claims",
    #   "action"=>"create",
    #   "education_career_counseling_claim"=>{
    #     "status"=>"isVeteran",
    #     "claimant_address"=>{
    #       "country_name"=>"USA",
    #       "address_line1"=>"9417 Princess Palm",
    #       "city"=>"Tampa",
    #       "state_code"=>"FL",
    #       "zip_code"=>"33928"
    #     },
    #     "claimant_phone_number"=>"5555555555",
    #     "claimant_email_address"=>"cohnjesse@gmail.xom",
    #     "claimant_confirm_email_address"=>"cohnjesse@gmail.xom"
    #   }
    # }


    private

    def career_counseling_params
      params.require(:education_career_counseling_claim).permit(
        :status,
        :claimant_phone_number,
        :claimant_email_address,
        :claimant_confirm_email_address,
        claimant_address: {}
      )
    end

    def stats_key
      'api.education_career_counseling'
    end
  end
end