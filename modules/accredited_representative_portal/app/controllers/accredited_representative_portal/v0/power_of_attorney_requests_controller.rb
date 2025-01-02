# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        poa_requests = filtered_poa_requests.limit(100)
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

      def filtered_poa_requests
        return poa_requests_rel if params[:status].blank?
        return poa_requests_rel.none unless %w[pending completed].include?(params[:status]&.downcase)

        poa_requests_rel.send(params[:status].downcase)
      end

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
