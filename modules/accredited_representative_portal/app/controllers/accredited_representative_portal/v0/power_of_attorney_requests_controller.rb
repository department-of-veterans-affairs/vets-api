# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      module Statuses
        ALL = [
          PENDING = 'pending',
          PROCESSED = 'processed'
        ].freeze
      end

      include PowerOfAttorneyRequests

      before_action :authorize_poa_requests, only: [:index]
      before_action :set_poa_request, only: [:show]

      def index
        status = params[:status].presence
        rel =
          case status
          when Statuses::PENDING
            poa_request_scope.unresolved.order(created_at: :asc)
          when Statuses::PROCESSED
            poa_request_scope.resolved.not_expired.order('resolution.created_at DESC')
          when NilClass
            poa_request_scope
          else
            raise ActionController::BadRequest, <<~MSG.squish
              Invalid status parameter.
              Must be one of (#{Statuses::ALL.join(', ')})
            MSG
          end

        @poa_requests = rel.includes(scope_includes).limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_requests)

        render json: serializer.serializable_hash, status: :ok
      end

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end

      private

      def authorize_poa_requests
        authorize PowerOfAttorneyRequest
      end

      def set_poa_request
        id = params[:id]
        @poa_request = find_poa_request(id)

        authorize @poa_request
      end

      def scope_includes
        [
          :power_of_attorney_form,
          :accredited_individual,
          :accredited_organization,
          { resolution: :resolving }
        ]
      end
    end
  end
end
