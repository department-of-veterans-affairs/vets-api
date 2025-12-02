# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/lab_or_test_serializer'
require 'unique_user_events'

module MyHealth
  module V2
    class LabsAndTestsController < ApplicationController
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        labs = sort_records(service.get_labs(start_date:, end_date:), params[:sort])
        serialized_labs = UnifiedHealthData::LabOrTestSerializer.new(labs).serializable_hash[:data]

        # Log unique user events for labs accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED
          ]
        )

        render json: serialized_labs,
               status: :ok
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
