# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/condition_serializer'

module MyHealth
  module V2
    class ConditionsController < ApplicationController
      service_tag 'mhv-medical-records'

      def index
        conditions = service.get_conditions
        render json: UnifiedHealthData::Serializers::ConditionSerializer.new(conditions),
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e)
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
                       'An unexpected error occurred while retrieving conditions.',
                       '500', 500, :internal_server_error)
        end
      end

      def log_error(error)
        message = case error
                  when Common::Client::Errors::ClientError
                    "Conditions FHIR API error: #{error.message}"
                  when Common::Exceptions::BackendServiceException
                    "Backend service exception: #{error.errors.first&.detail}"
                  else
                    "Unexpected error in conditions controller: #{error.message}"
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
        UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
