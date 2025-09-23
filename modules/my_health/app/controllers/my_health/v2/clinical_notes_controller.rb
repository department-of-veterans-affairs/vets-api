# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/clinical_notes_serializer'

module MyHealth
  module V2
    class ClinicalNotesController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        care_notes = service.get_care_summaries_and_notes
        serialized_notes = UnifiedHealthData::ClinicalNotesSerializer.new(care_notes)
        render json: serialized_notes,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e)
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
        handle_error(e)
      end

      private

      def handle_error(error)
        log_error(error)

        case error
        when Common::Client::Errors::ClientError
          render_error('FHIR API Error', error.message, error.status, error.status, :bad_gateway)
        when Common::Exceptions::BackendServiceException
          render json: { errors: error.errors }, status: :bad_gateway
        else
          render_error('Internal Server Error',
                       'An unexpected error occurred while retrieving clinical notes.',
                       '500', 500, :internal_server_error)
        end
      end

      def log_error(error)
        message = case error
                  when Common::Client::Errors::ClientError
                    "Notes FHIR API error: #{error.message}"
                  when Common::Exceptions::BackendServiceException
                    "Backend service exception: #{error.errors.first&.detail}"
                  else
                    "Unexpected error in notes controller: #{error.message}"
                  end
        Rails.logger.error(message)
      end

      def render_error(title, detail, code, status, http_status)
        error = {
          title:,
          detail:,
          code:,
          status:
        }
        render json: { errors: [error] }, status: http_status
      end

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
