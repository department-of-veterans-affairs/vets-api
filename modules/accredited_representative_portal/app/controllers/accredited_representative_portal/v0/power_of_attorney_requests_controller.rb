# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        requests = PowerOfAttorneyRequest.includes(:resolution)
        render json: PowerOfAttorneyRequestSerializer.new(requests).serializable_hash, status: :ok
      end

      def show
        request = PowerOfAttorneyRequest.includes(:resolution).find(params[:id])
        render json: PowerOfAttorneyRequestSerializer.new(request).serializable_hash, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end

      private

      def authenticate; end
    end
  end
end
