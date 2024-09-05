# frozen_string_literal: true

module V0
  class EVSSClaimsAsyncController < ApplicationController
    include IgnoreNotFound
    service_tag 'claim-status'

    before_action { authorize :evss, :access? }

    def index
      claims, synchronized = service.all

      options = { meta: { sync_status: synchronized } }
      render json: EVSSClaimListSerializer.new(claims, options)
    end

    def show
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])

      # No record in DB of a claim with that ID being associated with current_user
      if claim.blank?
        # Pull the list of claims so that the DB (potentially) gets populated
        EVSSClaimService.new(current_user).all

        # Check to see if a record is there now
        claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])

        # Still no record in the DB, safe to assume that the claim doesn't belong to
        # current_user
        unless claim
          Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
          raise Common::Exceptions::RecordNotFound, params[:id]
        end
      end

      claim, synchronized = service.update_from_remote(claim)
      options = { meta: { sync_status: synchronized } }
      render json: EVSSClaimDetailSerializer.new(claim, options)
    end

    private

    def service
      EVSSClaimServiceAsync.new(current_user)
    end
  end
end
