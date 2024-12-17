# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        data = policy_scope(PowerOfAttorneyRequest)
        render json: { data: data, meta: { totalRecords: data.size } }
      end

      def show
        authorize
        render json: ::AccreditedRepresentativePortal::PENDING_POA_REQUEST_MOCK_DATA
      end
    end
  end
end
