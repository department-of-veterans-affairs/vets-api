# frozen_string_literal: true

module V0
  class EVSSClaimsController < ApplicationController
    include IgnoreNotFound

    before_action { authorize :evss, :access? }

    def index
      claims, synchronized = service.all
      render json: claims,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: EVSSClaimListSerializer,
             meta: { successful_sync: synchronized }
    end

    def show
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
      unless claim
        Raven.tags_context(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::RecordNotFound, params[:id]
      end

      claim, synchronized = service.update_from_remote(claim)
      render json: claim, serializer: EVSSClaimDetailSerializer,
             meta: { successful_sync: synchronized }
    end

    def request_decision
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
      unless claim
        Raven.tags_context(team: 'benefits-memorial-1') # tag sentry logs with team name
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
