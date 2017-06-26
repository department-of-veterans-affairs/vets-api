# frozen_string_literal: true
module V0
  class PensionClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      claim = SavedClaim::Pension.new(form: pension_claim_params[:form])
      unless claim.save
        validation_error = claim.errors.full_messages.join(', ')

        log_message_to_sentry(validation_error, :error, {}, validation: 'pension_claim')

        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
      claim.process_attachments!
      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{SavedClaim::Pension::FORM}"
      render(json: claim)
    end

    private

    def pension_claim_params
      params.require(:pension_claim).permit(:form)
    end

    def stats_key
      'api.pension_claim'
    end
  end
end
