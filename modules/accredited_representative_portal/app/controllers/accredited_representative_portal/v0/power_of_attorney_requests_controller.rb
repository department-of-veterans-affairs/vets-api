# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        poa_requests = PowerOfAttorneyRequest.includes(resolution: :resolving).limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

        render json: serializer.serializable_hash, status: :ok
      end

      def show
        poa_request = PowerOfAttorneyRequest.includes(resolution: :resolving).find(params[:id])
        serializer = PowerOfAttorneyRequestSerializer.new(poa_request)
        render json: serializer.serializable_hash, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end
    end
  end
end
