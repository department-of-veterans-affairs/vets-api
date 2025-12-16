# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/condition_serializer'
require 'unique_user_events'

module MyHealth
  module V2
    class ConditionsController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        conditions = sort_records(service.get_conditions, params[:sort])

        # Log unique user events for conditions accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_CONDITIONS_ACCESSED
          ]
        )

        render json: UnifiedHealthData::Serializers::ConditionSerializer.new(conditions),
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'conditions', api_type: 'FHIR')
      end

      def show
        condition = service.get_single_condition(params[:id])
        unless condition
          render_error('Condition Not Found',
                       'The requested condition record was not found',
                       '404', 404, :not_found)
          return
        end
        serialized_condition = UnifiedHealthData::Serializers::ConditionSerializer.new(condition)
        render json: serialized_condition,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'conditions', api_type: 'FHIR')
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
