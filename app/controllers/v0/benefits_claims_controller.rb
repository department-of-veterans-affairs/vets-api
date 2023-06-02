# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module V0
  class BenefitsClaimsController < ApplicationController
    before_action { authorize :lighthouse, :access? }

    def index
      claims = service.get_claims

      render json: claims
    end

    def show
      claim = service.get_claim(params[:id])

      render json: claim
    end

    def submit5103
      res = service.submit5103(params[:id])

      render json: res
    end

    private

    def service
      @service ||= BenefitsClaims::Service.new(@current_user.icn)
    end
  end
end
