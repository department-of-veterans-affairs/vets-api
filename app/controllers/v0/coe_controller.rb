# frozen_string_literal: true

require 'lgy/service'

module V0
  class CoeController < ApplicationController
    def status
      coe_status = lgy_service.coe_status
      render json: { data: { attributes: coe_status } }, status: :ok
    end

    def download_coe
      coe_url = lgy_service.coe_url
      render json: { data: { attributes: { url: coe_url } } }, status: :ok
    end

    def submit_coe_claim
      load_user
      claim = SavedClaim::CoeClaim.new(form: filtered_params[:form])

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.send_to_lgy(edipi: current_user.edipi, icn: current_user.icn)

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)
      render(json: claim)
    end

    private

    def lgy_service
      @lgy_service ||= LGY::Service.new(edipi: @current_user.edipi, icn: @current_user.icn)
    end

    def filtered_params
      params.require(:lgy_coe_claim).permit(:form)
    end

    def stats_key
      'api.lgy_coe'
    end
  end
end
