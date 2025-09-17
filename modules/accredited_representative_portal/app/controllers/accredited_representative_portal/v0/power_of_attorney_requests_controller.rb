# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      include PowerOfAttorneyRequests
      include AccreditedRepresentativePortal::V0::WithdrawalGuard

      before_action do
        authorize PowerOfAttorneyRequest
      end
      with_options only: :show do
        before_action do
          id = params[:id]
          set_poa_request(id)
          render_404_if_withdrawn!(@poa_request)
        end
      end

      def index
        ar_monitoring.trace('ar.power_of_attorney_requests.index',
                            tags: { 'poa_request.poa_codes' => poa_codes(poa_requests) }) do |_span|
          serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)
          render json: {
            data: serializer.serializable_hash,
            meta: pagination_meta(poa_requests)
          }, status: :ok
        end
      end

      def show
        ar_monitoring.trace('ar.power_of_attorney_requests.show',
                            tags: { 'poa_request.poa_code' => poa_code },
                            root_tags: { 'poa_request.poa_code' => poa_code }) do |_span|
          serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
          render json: serializer.serializable_hash, status: :ok
        end
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
                          .then { |it| filter_by_current_user(it) }
                          .unredacted
                          .preload(scope_includes)
                          .then do |it|
          if sort_params.present?
            it.sorted_by(sort_params[:by],
                         sort_params[:order])
          else
            it
          end
        end
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

      def as_selected_individual?
        params[:as_selected_individual].present? && params[:as_selected_individual] == 'true'
      end

      def filter_by_current_user(relation)
        return relation unless as_selected_individual?

        relation.for_accredited_individual(
          current_user.registration_numbers
        )
      rescue => e
        Rails.logger.error("Error filtering by current user as selected individual: #{e.message}")
        relation
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

      def poa_code
        @poa_request.power_of_attorney_holder_poa_code
      end

      def poa_codes(poa_requests)
        poa_requests.map(&:power_of_attorney_holder_poa_code).uniq.join(',')
      end

      def ar_monitoring
        @ar_monitoring ||= AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: [
            "controller:#{controller_name}",
            "action:#{action_name}"
          ].compact
        )
      end
    end
  end
end
