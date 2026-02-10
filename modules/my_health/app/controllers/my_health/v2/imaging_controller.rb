# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/imaging_study_serializer'

module MyHealth
  module V2
    class ImagingController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        imaging_study_type = params[:imaging_study_type] || 'ALL'

        imaging_studies = sort_records(
          service.get_imaging_studies(
            start_date:,
            end_date:,
            imaging_study_type:
          ),
          params[:sort]
        )
        serialized_studies = UnifiedHealthData::Serializers::ImagingStudySerializer.new(imaging_studies).serializable_hash[:data]

        render json: serialized_studies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'imaging studies', api_type: 'FHIR')
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
