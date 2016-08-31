# frozen_string_literal: true
module V0
  class ClaimsController < ApplicationController
    skip_before_action :authenticate

    def index
      render json: current_user.claims,
             serializer: ActiveModel::Serializer::CollectionSerializer,
             each_serializer: ClaimSerializer
    end

    private

    def current_user
      @current_user ||= User.new
    end
  end
end
