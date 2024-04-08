# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < ClaimsApi::V2::ApplicationController
      def index
        render json: {}
      end
    end
  end
end
