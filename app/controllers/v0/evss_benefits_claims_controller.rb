# frozen_string_literal: true

module V0
  class EVSSBenefitsClaimsController < ApplicationController
    include IgnoreNotFound
    include V0::Concerns::EVSSDeprecation
    service_tag 'claim-status'

    before_action { authorize :evss, :access? }

    def index
      claims = get_claims
      claims = add_deprecation_metadata(claims)

      render json: claims
    end

    def show
      claim = get_claim(params[:id])
      claim = add_deprecation_metadata(claim)

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
      # Make sure that the claim ID belongs to the authenticated user
      claim = EVSSClaim.for_user(current_user).find_by(evss_id:)

      raise Common::Exceptions::RecordNotFound, params[:id] unless claim

      headers = get_auth_headers
      EVSS::ClaimsService.new(headers).find_claim_with_docs_by_id(evss_id).body
    end
  end
end
