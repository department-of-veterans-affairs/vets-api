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

        rel = filter_by_status(rel, status)

        poa_requests = rel.includes(scope_includes).limit(100)

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

        render json: serializer.serializable_hash, status: :ok
      end

      def show
        serializer = PowerOfAttorneyRequestSerializer.new(@poa_request)
        render json: serializer.serializable_hash, status: :ok
      end

      private

      def filter_by_status(rel, status)
        case status
        when Statuses::PENDING
          rel.unresolved.order(created_at: :asc)
        when Statuses::PROCESSED
          rel.resolved.not_expired.order('resolution.created_at DESC')
        when NilClass
          rel
        else
          raise ActionController::BadRequest, <<~MSG.squish
            Invalid status parameter.
            Must be one of (#{Statuses::ALL.join(', ')})
          MSG
        end
      end

      module Statuses
        ALL = [
          PENDING = 'pending',
          PROCESSED = 'processed'
        ].freeze
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
