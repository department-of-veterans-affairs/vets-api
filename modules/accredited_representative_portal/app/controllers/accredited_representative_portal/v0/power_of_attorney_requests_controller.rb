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
          set_poa_request(id)
        end
      end

      def index
        status = params[:status].presence
        rel = policy_scope(PowerOfAttorneyRequest)

        rel =
          case status
          when Statuses::PENDING
            rel.unresolved.order(created_at: :asc)
          when Statuses::PROCESSED
            rel.resolved.not_expired.order('resolution.created_at DESC')
          when NilClass
            rel
          else
            message = "Invalid status parameter. Must be one of (#{Statuses::ALL.join(', ')})"
            log_warn(message, 'poa_requests.invalid_status', ["status:#{status}"])
            raise ActionController::BadRequest, message.squish
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

      module Statuses
        ALL = [
          PENDING = 'pending',
          PROCESSED = 'processed'
        ].freeze
      end

      def authorize_poa_requests
        authorize PowerOfAttorneyRequest
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
