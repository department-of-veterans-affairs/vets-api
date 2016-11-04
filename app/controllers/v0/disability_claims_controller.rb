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
      claim = DisabilityClaim.for_user(current_user).find(params[:id])
      claim, synchronized = claim_service.update_from_remote(claim)
      render json: claim, serializer: DisabilityClaimDetailSerializer,
             meta: { successful_sync: synchronized }
    end

    def request_decision
      claim = DisabilityClaim.for_user(current_user).find(params[:id])
      jid = claim_service.request_decision(claim)
      render_job_id(jid)
    end
  end
end
