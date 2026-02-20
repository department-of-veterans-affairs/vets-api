# frozen_string_literal: true

require 'unified_health_data/imaging_service'
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
        imaging_study_type = params[:imaging_study_type].presence || 'ALL'
        site_ids = user_site_ids

        imaging_studies = sort_records(
          service.get_imaging_studies(
            start_date:,
            end_date:,
            imaging_study_type:,
            site_ids:
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

      def thumbnails
        # NOTE: params[:id] is a FHIR imaging study identifier URN (e.g. 'urn-vastudy-...')
        record_id = params[:id]

        imaging_studies = service.get_imaging_study(
          start_date: default_start_date,
          end_date: default_end_date,
          record_id:
        )
        serialized_studies = UnifiedHealthData::Serializers::ImagingStudySerializer.new(imaging_studies).serializable_hash[:data]

        render json: serialized_studies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'imaging study', api_type: 'FHIR')
      end

      def dicom
        # NOTE: params[:id] is a FHIR imaging study identifier URN (e.g. 'urn-vastudy-...')
        record_id = params[:id]

        imaging_studies = service.get_dicom_zip(
          start_date: default_start_date,
          end_date: default_end_date,
          record_id:
        )
        serialized_studies = UnifiedHealthData::Serializers::ImagingStudySerializer.new(imaging_studies).serializable_hash[:data]

        render json: serialized_studies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'DICOM zip', api_type: 'FHIR')
      end

      private

      def service
        @service ||= UnifiedHealthData::ImagingService.new(@current_user)
      end

      # SCDF requires date params for thumbnails and DICOM but they do not
      # affect results. Provide a wide window so every study qualifies.
      def default_start_date
        10.years.ago.strftime('%Y-%m-%d')
      end

      def default_end_date
        1.year.from_now.strftime('%Y-%m-%d')
      end

      # Combines the user's VistA treatment facility IDs and Cerner (Oracle Health)
      # facility IDs to build the full list of sites for SCDF imaging queries.
      def user_site_ids
        vista_ids = @current_user.va_treatment_facility_ids || []
        cerner_ids = @current_user.cerner_facility_ids || []
        (vista_ids + cerner_ids).map(&:to_s).uniq
      end
    end
  end
end
