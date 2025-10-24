# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/lab_or_test_serializer'
require 'unique_user_events'

module Mobile
  module V1
    class LabsAndTestsController < ApplicationController
      service_tag 'mhv-medical-records'

      before_action :controller_enabled?

      def index
        start_date = params[:startDate]
        end_date = params[:endDate]
        labs = service.get_labs(start_date:, end_date:)

        # Log unique user events for labs accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED
          ]
        )

        render json: UnifiedHealthData::LabOrTestSerializer.new(labs)
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
