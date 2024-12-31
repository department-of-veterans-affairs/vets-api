# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        poa_requests = poa_requests_rel.limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

        render json: serializer.serializable_hash, status: :ok
      end

      def show
        poa_request = poa_requests_rel.find(params[:id])
        serializer = PowerOfAttorneyRequestSerializer.new(poa_request)

        render json: serializer.serializable_hash, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end

      private

      def poa_requests_rel
        PowerOfAttorneyRequest.includes(
          :power_of_attorney_form,
          :power_of_attorney_holder,
          :accredited_individual,
          resolution: :resolving
        )
      end
    end
  end
end
