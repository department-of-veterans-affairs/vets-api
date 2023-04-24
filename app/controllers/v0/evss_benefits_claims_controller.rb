# frozen_string_literal: true

module V0
  class EVSSBenefitsClaimsController < ApplicationController
    include IgnoreNotFound

    before_action { authorize :evss, :access? }

    def index
      claims = get_claims

      render json: claims
    end

    def show
      claim = get_claim(params[:id])

      render json: claim
    end

    private

    def get_auth_headers
      EVSS::AuthHeaders.new(@current_user).to_h
    end

    def get_claims
      headers = get_auth_headers
      EVSS::ClaimsService.new(headers).all_claims.body
    end

    def get_claim(evss_id)
      headers = get_auth_headers
      EVSS::ClaimsService.new(headers).find_claim_with_docs_by_id(evss_id).body
    end
  end
end
