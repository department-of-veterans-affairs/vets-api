# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/allergy_serializer'

module MyHealth
  module V2
    class AllergiesController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        allergies = service.get_allergies
        serialized_allergies = UnifiedHealthData::AllergySerializer.new(allergies)
        render json: serialized_allergies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e)
      end

      def show
        allergy = service.get_single_allergy(params['id'])
        unless allergy
          render_error('Record Not Found',
                       'The requested record was not found',
                       '404', 404, :not_found)
          return
        end
        serialized_allergy = UnifiedHealthData::AllergySerializer.new(allergy)
        render json: serialized_allergy,
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
