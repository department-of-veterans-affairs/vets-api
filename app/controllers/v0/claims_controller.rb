# frozen_string_literal: true
module V0
  class ClaimsController < ApplicationController
    skip_before_action :authenticate

    def index
      render json: current_user.claims,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: ClaimSerializer
    end

    def request_decision
      current_user.request_claim_decision(params[:id])
      head :no_content
    end

    private

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
