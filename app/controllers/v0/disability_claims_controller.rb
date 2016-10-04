# frozen_string_literal: true
module V0
  class DisabilityClaimsController < ApplicationController
    skip_before_action :authenticate

    def index
      render json: claim_service.all,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: DisabilityClaimBaseSerializer
    end

    def show
      claim = DisabilityClaim.for_user(current_user).find(params[:id])
      claim = claim_service.update_from_remote(claim)
      render json: claim, serializer: DisabilityClaimDetailSerializer
    end

    def request_decision
      claim = DisabilityClaim.for_user(current_user).find(params[:id])
      claim_service.request_decision(claim)
      head :no_content
    end

    private

    def claim_service
      @claim_service ||= DisabilityClaimService.new(current_user)
    end

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
