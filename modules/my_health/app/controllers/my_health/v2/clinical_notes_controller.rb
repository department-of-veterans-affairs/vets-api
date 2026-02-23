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
      before_action :validate_source_param, only: :show

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        result = service.get_care_summaries_and_notes(start_date:, end_date:)
        care_notes = sort_records(result[:records], params[:sort])
        serialized_notes = UnifiedHealthData::ClinicalNotesSerializer.new(care_notes).serializable_hash[:data]

        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_NOTES_ACCESSED
          ]
        )

        render json: build_response(serialized_notes, result[:warnings]),
               status: :ok
      rescue ArgumentError => e
        render_error('Invalid Parameter', e.message, '400', 400, :bad_request)
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'clinical notes', api_type: 'FHIR')
      end

      def show
        care_note = service.get_single_summary_or_note(params['id'], source: params['source'])
        if care_note.nil?
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

      def build_response(data, warnings)
        response = { data: }
        response[:meta] = { warnings: } if warnings.present?
        response
      end

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def valid_sources
        [UnifiedHealthData::SourceConstants::ORACLE_HEALTH, UnifiedHealthData::SourceConstants::VISTA]
      end

      def validate_source_param
        source = params['source']

        if source.blank?
          render_error('Record Not Found',
                       'The requested record was not found. A source parameter is required.',
                       '400', 400, :bad_request)
        elsif source == UnifiedHealthData::SourceConstants::VISTA
          render_error('Invalid Parameter',
                       'VistA notes are not available for direct lookup. Use source=oracle-health.',
                       '400', 400, :bad_request)
        elsif !valid_source?(source)
          render_error('Invalid Parameter',
                       "Invalid source: '#{source}'. Must be one of: #{valid_sources.join(', ')}",
                       '400', 400, :bad_request)
        end
      end

      def valid_source?(source)
        valid_sources.include?(source)
      end
    end
  end
end
