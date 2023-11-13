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
  end

  # Creates and validates an instance of the class, removing any copies of
  # the form that had been previously saved by the user.
  def create
    PensionBurial::TagSentry.tag_sentry

    claim = claim_class.new(form: filtered_params[:form])
    unless claim.save
      StatsD.increment("#{stats_key}.failure")
      raise Common::Exceptions::ValidationErrors, claim
    end

    use_lighthouse = Flipper.enabled?(:pension_claim_submission_to_lighthouse)
    unless use_lighthouse
      claim.process_attachments!
    else
      claim.upload_to_lighthouse
    end

    StatsD.increment("#{stats_key}.success")
    Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"

    clear_saved_form(claim.form_id)
    render(json: claim)
  end

end
