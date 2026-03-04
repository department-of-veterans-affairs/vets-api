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
        result = service.get_labs(start_date:, end_date:, caller: 'web_v2')
        labs = sort_records(result[:records], params[:sort])
        serialized_labs = UnifiedHealthData::LabOrTestSerializer.new(labs).serializable_hash[:data]

        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED
          ]
        )

        render json: build_response(serialized_labs, result[:warnings]),
               status: :ok
      end

      private

      def build_response(data, warnings)
        response = { data: }
        response[:meta] = { warnings: } if warnings.present?
        response
      end

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
