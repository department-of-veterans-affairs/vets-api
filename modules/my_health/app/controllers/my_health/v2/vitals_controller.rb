# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/vital_serializer'

module MyHealth
  module V2
    class VitalsController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        vitals = service.get_vitals
        serialized_vitals = UnifiedHealthData::VitalSerializer.new(vitals)
        render json: serialized_vitals,
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
          render_error('SCDF API Error', error.message, error.status, error.status, :bad_gateway)
        when Common::Exceptions::BackendServiceException
          render json: { errors: error.errors }, status: :bad_gateway
        else
          render_error('Internal Server Error',
                       'An unexpected error occurred while retrieving vitals.',
                       '500', 500, :internal_server_error)
        end
      end

      def log_error(error)
        message = case error
                  when Common::Client::Errors::ClientError
                    "Vitals SCDF API error: #{error.message}"
                  when Common::Exceptions::BackendServiceException
                    "Backend service exception: #{error.errors.first&.detail}"
                  else
                    "Unexpected error in vitals controller: #{error.message}"
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
