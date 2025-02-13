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
            rel.pending.order(created_at: :asc)
          when Statuses::PROCESSED
            rel.processed.not_expired.order('resolution.created_at DESC')
          when NilClass
            rel
          else
            raise ActionController::BadRequest, <<~MSG.squish
              Invalid status parameter.
              Must be one of (#{Statuses::ALL.join(', ')})
            MSG
          end

        poa_requests = rel.includes(scope_includes).limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

        render json: serializer.serializable_hash, status: :ok
      end

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end

      private

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
