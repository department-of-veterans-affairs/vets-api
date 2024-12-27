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
        if poa_request && authorize(poa_request, :show?, policy_class: PowerOfAttorneyRequestsPolicy)
          serializer = PowerOfAttorneyRequestSerializer.new(poa_request)
          render json: serializer.serializable_hash, status: :ok
        else
          render json: { error: 'Record not found' }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end

      private

      def poa_request
        poa_requests_rel.find(params[:id])
      end

      def poa_requests_rel
        policy_scope(PowerOfAttorneyRequest, policy_scope_class: PowerOfAttorneyRequestsPolicy::Scope)
      end
    end
  end
end
