# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        render json: policy_scope(PowerOfAttorneyRequestsPolicy)
      end

      def show
        render json: POA_REQUEST_ITEM_MOCK_DATA
      end
    end
  end
end
