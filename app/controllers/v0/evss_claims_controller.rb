# frozen_string_literal: true

module V0
  class EVSSClaimsController < EVSSBaseController
    include IgnoreNotFound

    def index
      claims, synchronized = service.all
      render json: claims,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: EVSSClaimListSerializer,
             meta: { successful_sync: synchronized }
    end

    def show
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
      raise Common::Exceptions::RecordNotFound, params[:id] unless claim
      claim, synchronized = service.update_from_remote(claim)
      render json: claim, serializer: EVSSClaimDetailSerializer,
             meta: { successful_sync: synchronized }
    end

    def request_decision
      claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
      raise Common::Exceptions::RecordNotFound, params[:id] unless claim
      jid = service.request_decision(claim)
      claim.update_attributes(requested_decision: true)
      render_job_id(jid)
    end

    private

    def service
      @claim_service ||= EVSSClaimService.new(current_user)
    end
  end
end
