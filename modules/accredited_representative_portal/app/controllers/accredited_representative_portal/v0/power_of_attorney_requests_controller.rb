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

        rel = poa_request_scope

        if params[:status]&.downcase == 'pending'
          rel = rel.unresolved
        elsif params[:status]&.downcase == 'completed'
          rel = rel.resolved
        elsif params[:status].present? # throw 400 for other non-blank statuses
          raise Common::Exceptions::BadRequest.new(
            errors: "Invalid status parameter. Values accepted: 'pending' or 'completed'."
          )
        end

        poa_requests = rel.includes(includes).limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)
        render json: serializer.serializable_hash, status: :ok
      end

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end
    end
  end
end
