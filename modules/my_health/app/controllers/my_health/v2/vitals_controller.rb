# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/vital_serializer'

module MyHealth
  module V2
    class VitalsController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        vitals = sort_records(service.get_vitals, params[:sort])

        serialized_vitals = UnifiedHealthData::VitalSerializer.new(vitals)
        render json: serialized_vitals,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'vitals', api_type: 'SCDF')
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
