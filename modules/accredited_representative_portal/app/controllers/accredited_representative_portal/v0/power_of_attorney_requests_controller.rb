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

      # rubocop:disable Metrics/MethodLength
      def index
        # Validate and normalize pagination parameters
        validated_params = PowerOfAttorneyRequestService::ParamsSchema.validate_and_normalize!(params.to_unsafe_h)
        page_params = validated_params[:page]

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

        poa_requests = relation
                       .includes(scope_includes)
                       .paginate(page: page_params[:number], per_page: page_params[:size])

        # Add pagination headers for API clients
        response.headers['X-Total'] = poa_requests.total_entries.to_s
        response.headers['X-Total-Pages'] = poa_requests.total_pages.to_s
        response.headers['X-Per-Page'] = poa_requests.per_page.to_s
        response.headers['X-Page'] = poa_requests.current_page.to_s

        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)
        render json: {
          data: serializer.serializable_hash,
          meta: {
            pagination: {
              current_page: poa_requests.current_page,
              per_page: poa_requests.per_page,
              total_pages: poa_requests.total_pages,
              total_count: poa_requests.total_entries
            }
          }
        }, status: :ok
      end
      # rubocop:enable Metrics/MethodLength

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
