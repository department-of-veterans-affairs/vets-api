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
        serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

        render json: {
          data: serializer.serializable_hash,
          meta: pagination_meta(poa_requests)
        }, status: :ok
      end

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end

      private

      def params_schema
        PowerOfAttorneyRequestService::ParamsSchema
      end

      def validated_params
        @validated_params ||= params_schema.validate_and_normalize!(params.to_unsafe_h)
      end

      def poa_requests
        @poa_requests ||= filter_by_status(policy_scope(PowerOfAttorneyRequest))
                          .then { |it| sort_params.present? ? it.sorted_by(sort_params[:by], sort_params[:order]) : it }
                          .unredacted
                          .preload(scope_includes)
                          .paginate(page:, per_page:)
      end

      def filter_by_status(relation)
        case status
        when params_schema::Statuses::PENDING
          pending(relation)
        when params_schema::Statuses::PROCESSED
          processed(relation)
        when NilClass
          relation
        else
          raise ActionController::BadRequest, <<~MSG.squish
            Invalid status parameter.
            Must be one of (#{Statuses::ALL.join(', ')})
          MSG
        end
      end

      def sort_params
        validated_params.fetch(:sort, {})
      end

      def page
        validated_params.dig(:page, :number)
      end

      def per_page
        validated_params.dig(:page, :size)
      end

      def status
        validated_params.fetch(:status, nil)
      end

      def pending(relation)
        query = relation.not_processed
        return query if sort_params.present?

        query.order(created_at: :desc)
      end

      def processed(relation)
        query = relation.processed.decisioned
        return query if sort_params.present?

        query.order(resolution: { created_at: :desc })
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
            totalPages: poa_requests.total_pages
          }
        }
      end
    end
  end
end
