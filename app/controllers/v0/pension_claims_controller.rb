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

    def create
      PensionBurial::TagSentry.tag_sentry

      claim = claim_class.new(form: filtered_params[:form])
      user_uuid = current_user&.uuid
      Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{user_uuid}"
      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end

      use_lighthouse = Flipper.enabled?(:pension_claim_submission_to_lighthouse)
      if use_lighthouse
        claim.upload_to_lighthouse
      else
        claim.process_attachments!
      end

      StatsD.increment("#{stats_key}.success")
      logs = ["Submitted job ClaimID=#{claim.confirmation_number}",
              "Form=#{claim.class::FORM} UserID=#{user_uuid}"]
      Rails.logger.info logs.join(' ')

      clear_saved_form(claim.form_id)
      render(json: claim)
    end
  end
end
