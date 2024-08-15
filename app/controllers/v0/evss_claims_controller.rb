# frozen_string_literal: true

module V0
  class EVSSClaimsController < ApplicationController
    include IgnoreNotFound
    service_tag 'claim-status'

    before_action { authorize :evss, :access? }

    def index
      claims, synchronized = service.all

      options = { meta: { successful_sync: synchronized } }
      render json: EVSSClaimListSerializer.new(claims, options)
    end

    def show
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
      unless claim
        Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::RecordNotFound, params[:id]
      end

      claim, synchronized = service.update_from_remote(claim)
      options = { meta: { successful_sync: synchronized } }
      render json: EVSSClaimDetailSerializer.new(claim, options)
    end

    def request_decision
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
      unless claim
        Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::RecordNotFound, params[:id]
      end

      jid = service.request_decision(claim)
      claim.update(requested_decision: true)
      render_job_id(jid)
    end

    private

    def skip_sentry_exception_types
      super + [Common::Exceptions::BackendServiceException]
    end

    def service
      EVSSClaimService.new(current_user)
    end
  end
end
