# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      include PowerOfAttorneyRequests

      before_action do
        authorize PowerOfAttorneyRequest
      end

      with_options only: :show do
        before_action do
          id = params[:id]
          find_poa_request(id)
        end
      end

      def index
        includes = [
          :power_of_attorney_form,
          :power_of_attorney_holder,
          :accredited_individual,
          { resolution: :resolving }
        ]

        poa_requests = filtered_poa_requests.includes(includes).limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)
        render json: serializer.serializable_hash, status: :ok
      end

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end

      private

      def filtered_poa_requests
        return poa_request_scope if params[:status].blank?
        return poa_request_scope.none unless %w[pending completed].include?(params[:status]&.downcase)

        poa_request_scope.send(params[:status].downcase)
      end
    end
  end
end
