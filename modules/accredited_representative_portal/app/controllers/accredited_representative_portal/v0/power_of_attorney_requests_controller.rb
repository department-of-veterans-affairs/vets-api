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
        # Parallel decrypt all encrypted fields
        Parallel.map(poa_requests, in_threads: poa_requests.size) do |request|
          request.tap do |r|
            if r.power_of_attorney_form.present?
              form = r.power_of_attorney_form
              form.data                # Main form data
              form.claimant_city      # Location fields
              form.claimant_state_code
              form.claimant_zip_code
            end

            if r.resolution.present?
              r.resolution.reason     # Resolution reason
            end

            if r.form_submission.present?
              sub = r.form_submission
              sub.service_response    # Service response
              sub.error_message      # Error details
            end
          end
        end

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

      module Statuses
        ALL = [
          PENDING = 'pending',
          PROCESSED = 'processed'
        ].freeze
      end

      def validated_params
        @validated_params ||= PowerOfAttorneyRequestService::ParamsSchema.validate_and_normalize!(params.to_unsafe_h)
      end

      def poa_requests
        @poa_requests ||= filter_by_status(policy_scope(PowerOfAttorneyRequest))
                          .includes(scope_includes).paginate(page:, per_page:)
      end

      def filter_by_status(relation)
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
      end

      def page
        validated_params[:page][:number]
      end

      def per_page
        validated_params[:page][:size]
      end

      def status
        params[:status].presence
      end

      def pending(relation)
        relation.not_processed.order(created_at: :desc)
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
