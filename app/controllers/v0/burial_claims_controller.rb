# frozen_string_literal: true

require 'pension_burial/tag_sentry'

module V0
  class BurialClaimsController < ClaimsBaseController
    def create
      PensionBurial::TagSentry.tag_sentry
      claim = claim_class.new(form: filtered_params[:form])

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      # this method also calls claim.process_attachments!
      claim.submit_to_structured_data_services!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)
      render(json: claim)
    end

    def short_name
      'burial_claim'
    end

    def claim_class
      SavedClaim::Burial
    end
  end
end
