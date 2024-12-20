# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        data = policy_scope(PowerOfAttorneyRequest)
        render json: { data: data, meta: { totalRecords: data.size } }
      end

      def show
        if poa_request && authorize(poa_request, :show?, policy_class: AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy)
          render json: { data: poa_request }
        else
          head :not_found
        end
      end

      private

      def poa_request
        ::AccreditedRepresentativePortal::POA_REQUEST_LIST_MOCK_DATA.find do |poa|
          poa[:id].to_s == params['id']
        end
      end
    end
  end
end
