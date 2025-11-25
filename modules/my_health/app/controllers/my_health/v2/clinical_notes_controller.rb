# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/clinical_notes_serializer'
require 'unique_user_events'

module MyHealth
  module V2
    class ClinicalNotesController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        care_notes = sort_records(service.get_care_summaries_and_notes(start_date:, end_date:), params[:sort])
        serialized_notes = UnifiedHealthData::ClinicalNotesSerializer.new(care_notes)

        # Log unique user events for clinical notes accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_NOTES_ACCESSED
          ]
        )

        render json: serialized_notes,
               status: :ok
      rescue ArgumentError => e
        render_error('Invalid Parameter', e.message, '400', 400, :bad_request)
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'clinical notes', api_type: 'FHIR')
      end

      def show
        care_note = service.get_single_summary_or_note(params['id'])
        unless care_note
          render_error('Record Not Found',
                       'The requested record was not found',
                       '404', 404, :not_found)
          return
        end
        serialized_note = UnifiedHealthData::ClinicalNotesSerializer.new(care_note)
        render json: serialized_note,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'clinical notes', api_type: 'FHIR')
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
