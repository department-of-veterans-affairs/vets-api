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
        relation = policy_scope(PowerOfAttorneyRequest)
        status = params[:status].presence

        relation =
          case status
          when Statuses::PENDING
            pending(relation)
          when Statuses::PROCESSED
            processed(relation)
          when NilClass
            relation
          else
            raise ActionController::BadRequest, <<~MSG.squish
              Invalid status parameter.
              Must be one of (#{Statuses::ALL.join(', ')})
            MSG
          end

        # `limit(100)` in case pagination isn't introduced quickly enough.
        poa_requests = relation.includes(scope_includes).limit(100)
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

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

      def pending(relation)
        relation
          .not_processed
          .order(created_at: :desc)
      end

      def processed(relation)
        relation.processed.decisioned.order(
          resolution: { created_at: :desc }
        )
      end

      def scope_includes
        [
          :power_of_attorney_form,
          :power_of_attorney_form_submission,
          :accredited_individual,
          :accredited_organization,
          { resolution: :resolving }
        ]
      end
    end
  end
end
