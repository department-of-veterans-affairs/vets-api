# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module V0
  class BenefitsClaimsController < ApplicationController
    before_action { authorize :lighthouse, :access? }
    service_tag 'claims-shared'

    def index
      claims = service.get_claims
      tap_claims(claims['data'])

      render json: claims
    end

    def show
      claim = service.get_claim(params[:id])

      # We want to log some details about claim type patterns to track in DataDog
      claim_info = claim['data']['attributes']
      ::Rails.logger.info('Claim Type Details',
                          { message_type: 'lh.cst.claim_types',
                            claim_type: claim_info['claimType'],
                            claim_type_code: claim_info['claimTypeCode'],
                            num_contentions: claim_info['contentions'].count,
                            ep_code: claim_info['endProductCode'],
                            claim_id: params[:id] })
      tap_claims([claim['data']])

      render json: claim
    end

    def submit5103
      res = service.submit5103(@current_user, params[:id])

      render json: res
    end

    private

    def claims_scope
      EVSSClaim.for_user(@current_user)
    end

    def service
      @service ||= BenefitsClaims::Service.new(@current_user.icn)
    end

    def tap_claims(claims)
      claims.each do |claim|
        record = claims_scope.where(evss_id: claim['id']).first

        if record.blank?
          EVSSClaim.create(
            user_uuid: @current_user.uuid,
            user_account: @current_user.user_account,
            evss_id: claim['id'],
            data: {}
          )
        end
      end
    end
  end
end
