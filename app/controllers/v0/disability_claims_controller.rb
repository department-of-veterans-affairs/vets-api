# frozen_string_literal: true
module V0
  class DisabilityClaimsController < DisabilityClaimsBaseController
    def index
      render json: claim_service.all,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: DisabilityClaimListSerializer
    end

    def show
      claim = DisabilityClaim.for_user(current_user).find(params[:id])
      claim = claim_service.update_from_remote(claim)
      render json: claim, serializer: DisabilityClaimDetailSerializer
    end

    def request_decision
      claim = DisabilityClaim.for_user(current_user).find(params[:id])
      jid = claim_service.request_decision(claim)
      render_job_id(jid)
    end
  end
end
