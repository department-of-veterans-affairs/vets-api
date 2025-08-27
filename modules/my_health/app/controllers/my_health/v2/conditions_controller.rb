# frozen_string_literal: true

require 'unified_health_data/condition_service'
require 'condition_serializer'
require 'common/client/errors'
require 'common/exceptions'

module MyHealth
  module V2
    class ConditionsController < ApplicationController
      service_tag 'mhv-medical-records'

      STATSD_KEY_PREFIX = 'api.my_health.conditions_v2'

      def index
        conditions = service.get_conditions
        serialized_conditions = conditions.map { |record| ConditionSerializer.serialize(record) }
        StatsD.gauge("#{STATSD_KEY_PREFIX}.count", serialized_conditions.length)
        render json: { data: serialized_conditions }
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e)
      end

      private

      def service
        UnifiedHealthData::ConditionService.new(@current_user)
      end

      def handle_error(error)
        log_error(error)

        case error
        when Common::Client::Errors::ClientError
          render_error('FHIR API Error', error.message, error.status, error.status, :bad_gateway)
        when Common::Exceptions::BackendServiceException
          render json: { errors: error.errors }, status: :bad_gateway
        else
          render_error('Internal Server Error',
                       'An unexpected error occurred while retrieving condition records',
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
                    "Unexpected error in conditions v2 controller: #{error.message}"
                  end
        Rails.logger.error(
          message:,
          feature: 'conditions_v2',
          patient_icn: @current_user&.icn,
          error_class: error.class.name
        )
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
    end
  end
end
