# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'lighthouse/veterans_health/models/immunization'
require 'lighthouse/veterans_health/serializers/immunization_serializer'
require 'common/client/errors'
require 'common/exceptions'

module MyHealth
  module V2
    class ImmunizationsController < ApplicationController
      service_tag 'mhv-medical-records'

      STATSD_KEY_PREFIX = 'api.my_health.immunizations'

      before_action :check_feature_toggle
      # skip_before_action :authenticate

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]

        begin
          response = client.get_immunizations(start_date:, end_date:)
          immunizations = Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer
                          .from_fhir_bundle(response.body)

          # Track the number of immunizations returned to the client
          StatsD.gauge("#{STATSD_KEY_PREFIX}.count", immunizations.length)

          render json: { data: immunizations }
        rescue Common::Client::Errors::ClientError,
               Common::Exceptions::BackendServiceException,
               StandardError => e
          handle_error(e)
        end
      end

      def show
        id = params[:id]
        start_date = params[:start_date]
        end_date = params[:end_date]

        begin
          response = client.get_immunizations(start_date:, end_date:)
          immunization = response.body['entry'].find { |entry| entry['resource']['id'] == id }

          unless immunization
            raise Common::Client::Errors::ClientError.new('Immunization not found',
                                                          status: 404)
          end
          return_value = Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer
                         .from_fhir(immunization['resource'])
          Rails.logger.debug { "Immunization found: #{return_value.inspect}" }

          render json: { data: return_value }
        rescue Common::Client::Errors::ClientError,
               Common::Exceptions::BackendServiceException,
               StandardError => e
          handle_error(e)
        end
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
                       'An unexpected error occurred while retrieving immunization records',
                       '500', 500, :internal_server_error)
        end
      end

      def log_error(error)
        message = case error
                  when Common::Client::Errors::ClientError
                    "Immunizations FHIR API error: #{error.message}"
                  when Common::Exceptions::BackendServiceException
                    "Backend service exception: #{error.errors.first&.detail}"
                  else
                    "Unexpected error in immunizations controller: #{error.message}"
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

      def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn)
      end

      def check_feature_toggle
        unless Flipper.enabled?(:mhv_accelerated_delivery_vaccines_enabled)
          error = {
            title: 'Feature Disabled',
            detail: 'The immunizations feature is currently disabled',
            code: '403',
            status: 403
          }
          render json: { errors: [error] }, status: :forbidden
        end
      end
    end
  end
end
