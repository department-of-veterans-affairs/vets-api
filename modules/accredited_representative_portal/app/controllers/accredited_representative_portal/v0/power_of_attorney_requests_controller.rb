# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        poa_requests = PowerOfAttorneyRequest.includes(resolution: :resolving).limit(100)
        render json: PowerOfAttorneyRequestSerializer.new(poa_requests).serializable_hash, status: :ok
      end

      def show
        poa_request = PowerOfAttorneyRequest.includes(resolution: :resolving).find(params[:id])
        render json: PowerOfAttorneyRequestSerializer.new(poa_request).serializable_hash, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end
    end
  end
end
