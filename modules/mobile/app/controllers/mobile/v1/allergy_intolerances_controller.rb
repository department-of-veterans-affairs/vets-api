# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/allergy_serializer'

module Mobile
  module V1
    class AllergyIntolerancesController < ApplicationController
      service_tag 'mhv-medical-records'

      before_action :controller_enabled?
      before_action :validate_feature_flag

      def index
        allergies = service.get_allergies
        paged, page_meta = paginate_allergies(allergies)
        serialized_allergies = UnifiedHealthData::AllergySerializer.new(paged, meta: page_meta[:meta])
        render json: serialized_allergies,
               status: :ok
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Caught BackendServiceException: #{e.message}")
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
      rescue => e
        Rails.logger.error("Caught unexpected error: #{e.class}, #{e.message}")
        raise e
      end

      private

      def validate_feature_flag
        return if Flipper.enabled?(:mhv_accelerated_delivery_allergies_enabled, @current_user)

        render json: {
          error: {
            code: 'FEATURE_NOT_AVAILABLE',
            message: 'This feature is not currently available'
          }
        }, status: :forbidden
      end

      def pagination_contract
        Mobile::V0::Contracts::PaginationBase.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size)
        )
      end

      def paginate_allergies(list)
        Mobile::PaginationHelper.paginate(list:, validated_params: pagination_contract)
      end

      def controller_enabled?
        routing_error unless Flipper.enabled?(:mhv_accelerated_delivery_uhd_enabled, @current_user)
      end

      def routing_error
        raise Common::Exceptions::RoutingError, params[:path]
      end

      def service
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
