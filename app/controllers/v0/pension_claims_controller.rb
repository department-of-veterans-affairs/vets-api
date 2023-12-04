# frozen_string_literal: true

module V0
  class PensionClaimsController < ClaimsBaseController
    service_tag 'pension-application'

    def short_name
      'pension_claim'
    end

    def claim_class
      SavedClaim::Pension
    end

    # Creates and validates an instance of the class, removing any copies of
    # the form that had been previously saved by the user.
    def create
      PensionBurial::TagSentry.tag_sentry
      claim = claim_class.new(form: filtered_params[:form])
      user_uuid = current_user&.uuid
      Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{user_uuid}"
      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.itf_datetime = in_progress_form.created_at if in_progress_form
      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
      claim.process_attachments!
      StatsD.increment("#{stats_key}.success")
      Rails.logger.info(
        "Submitted job ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM} UserID=#{user_uuid}"
      )
      clear_saved_form(claim.form_id)
      render(json: claim)
    end
  end
end
