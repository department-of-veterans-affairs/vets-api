# frozen_string_literal: true
module V0
  class ClaimsController < ApplicationController
    skip_before_action :authenticate

    def index
      render json: claim_service.all,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: ClaimBaseSerializer
    end

    def show
      claim = claim_service.find_by_evss_id(params[:id])
      render json: claim, serializer: ClaimDetailSerializer
    end

    def request_decision
      claim_service.request_decision(params[:id])
      head :no_content
    end

    private

    def claim_service
      @claim_service ||= ClaimService.new(current_user)
    end

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
