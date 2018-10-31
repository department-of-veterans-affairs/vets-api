# frozen_string_literal: true

module V0
  module Profile
    class GrantsController < ApplicationController
      def index
        render json: @current_user.to_json
      end
    end
  end
end