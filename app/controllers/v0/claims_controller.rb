# frozen_string_literal: true
module V0
  class ClaimsController < ApplicationController
    skip_before_action :authenticate

    def index
      render json: Claim.fetch_all(current_user),
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: ClaimBaseSerializer
    end

    def show
      claim = Claim.find_by_id(params[:id], current_user)
      render json: claim, serializer: ClaimDetailSerializer
    end

    def request_decision
      Claim.request_decision(params[:id], current_user)
      head :no_content
    end

    private

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
