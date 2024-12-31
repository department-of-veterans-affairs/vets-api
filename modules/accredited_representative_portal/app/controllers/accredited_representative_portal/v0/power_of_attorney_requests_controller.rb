# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def index
        normalized_filtered_params = normalize_params(filter_params)

        poa_requests, errors = FilterService.handle_filter(normalized_filtered_params)

        if errors.present?
          logger.error("Invalid search parameters: #{errors}")

          render json: { errors: errors }, status: :bad_request
        else
          serializer = PowerOfAttorneyRequestSerializer.new(poa_requests)

          render json: serializer.serializable_hash, status: :ok
        end
      end

      def show
        poa_request = poa_requests_rel.find(params[:id])
        serializer = PowerOfAttorneyRequestSerializer.new(poa_request)

        render json: serializer.serializable_hash, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end

      private

      def poa_requests_rel
        PowerOfAttorneyRequest.includes(
          :power_of_attorney_form,
          :power_of_attorney_holder,
          :accredited_individual,
          resolution: :resolving
        )
      end

      def filter_params
        params.permit(:status, :sort_direction, :sort_field, :page_number, :page_size).to_h
      end

      def normalize_params(params)
        params.transform_keys { |key| key.to_s.camelize(:lower).to_sym }
      end
    end
  end
end
