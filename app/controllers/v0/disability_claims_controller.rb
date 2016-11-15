# frozen_string_literal: true
module V0
  class DisabilityClaimsController < DisabilityClaimsBaseController
    def index
      claims, synchronized = claim_service.all
      render json: claims,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: DisabilityClaimListSerializer,
             meta: { successful_sync: synchronized }
    end

    def show
      claim = DisabilityClaim.for_user(current_user).find_by(evss_id: params[:id])
      raise Common::Exceptions::RecordNotFound, params[:id] unless claim
      claim, synchronized = claim_service.update_from_remote(claim)
      render json: claim, serializer: DisabilityClaimDetailSerializer,
             meta: { successful_sync: synchronized }
    end

    def request_decision
      claim = DisabilityClaim.for_user(current_user).find_by(evss_id: params[:id])
      raise Common::Exceptions::RecordNotFound, params[:id] unless claim
      jid = claim_service.request_decision(claim)
      claim.update_attributes(requested_decision: true)
      render_job_id(jid)
    end
  end
end
