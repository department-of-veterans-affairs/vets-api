# frozen_string_literal: true
module V0
  class BurialClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      claim = SavedClaim::Burial.new(form: burial_claim_params[:form])
      unless claim.save
        validation_error = claim.errors.full_messages.join(', ')
        log_message_to_sentry(validation_error, :error, {}, validation: 'burial_claim')

        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end

      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{SavedClaim::Burial::FORM}"
      render(json: claim)
    end

    private

    def burial_claim_params
      params.require(:burial_claim).permit(:form)
    end

    def stats_key
      'api.burial_claim'
    end
  end
end
