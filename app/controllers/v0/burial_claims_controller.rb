# frozen_string_literal: true

require 'pension_burial/tag_sentry'

module V0
  class BurialClaimsController < ClaimsBaseController
    service_tag 'burial-application'

    def create
     PensionBurial::TagSentry.tag_sentry
     
      if Flipper.enabled?(:va_burial_v2)
        claim = claim_class.new(form: filtered_params[:form], formV2: JSON.parse(filtered_params["form"])["formV2"])
      else
        claim = claim_class.new(form: filtered_params[:form])
      end

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end
      # this method also calls claim.process_attachments!
      claim.submit_to_structured_data_services!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.form_id}"
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
