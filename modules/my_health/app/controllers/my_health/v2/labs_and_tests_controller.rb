# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/lab_or_test_serializer'
require 'unique_user_events'

module MyHealth
  module V2
    class LabsAndTestsController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        result = service.get_labs(start_date:, end_date:)
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
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'labs and tests', api_type: 'FHIR')
      end

      private

      def build_response(data, warnings)
        return data if warnings.blank?

        { data:, meta: { warnings: } }
      end

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
