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
        schema = PowerOfAttorneyRequestService::ParamsSchema
        validated_params = schema.validate_and_normalize!(params.to_unsafe_h)
        page_params = validated_params.fetch(:page, {})
        sort_params = validated_params.fetch(:sort, {})
        status = validated_params.fetch(:status, nil)

        relation = policy_scope(PowerOfAttorneyRequest)

        relation = case status
                   when schema::Statuses::PENDING
                     pending(relation)
                   when schema::Statuses::PROCESSED
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
                       .then { |it| sort_params.present? ? it.sorted_by(sort_params[:by], sort_params[:order]) : it }
                       .includes(scope_includes)
                       .paginate(page: page_params[:number], per_page: page_params[:size])

        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)
        render json: {
          data: serializer.serializable_hash,
          meta: pagination_meta(poa_requests)
        }, status: :ok
      end
      # rubocop:enable Metrics/MethodLength

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end

      private

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

      def pagination_meta(poa_requests)
        {
          page: {
            number: poa_requests.current_page,
            size: poa_requests.limit_value,
            total: poa_requests.total_entries,
            total_pages: poa_requests.total_pages
          }
        }
      end
    end
  end
end
