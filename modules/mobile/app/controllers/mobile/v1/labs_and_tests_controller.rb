# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/lab_or_test_serializer'

module Mobile
  module V1
    class LabsAndTestsController < ApplicationController
      before_action :controller_enabled?

      def index
        start_date = params[:startDate]
        end_date = params[:endDate]
        labs = service.get_labs(start_date:, end_date:)
        response = UnifiedHealthData::LabOrTestSerializer.serialize(labs)
        render json: response
      end

      private

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
