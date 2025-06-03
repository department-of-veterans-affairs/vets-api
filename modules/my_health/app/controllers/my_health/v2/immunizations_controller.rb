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
      FEATURE_TOGGLE = 'mhv_medical_records_immunizations_v2_enabled'

      before_action :check_feature_toggle

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        
        begin
          response = client.get_immunizations(start_date:, end_date:)
          # log the request for debugging
          immunizations = Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer.from_fhir_bundle(response.body)
          
          # Track the number of immunizations returned to the client
          StatsD.gauge("#{STATSD_KEY_PREFIX}.count", immunizations.length)
          
          render json: { data: immunizations }
        rescue Common::Client::Errors::ClientError => e
          Rails.logger.error("Immunizations FHIR API error: #{e.message}")
          error = { 
            title: 'FHIR API Error',
            detail: e.message,
            code: e.status, 
            status: e.status
          }
          render json: { errors: [error] }, status: :bad_gateway
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error("Backend service exception: #{e.errors.first&.detail}")
          render json: { errors: e.errors }, status: :bad_gateway
        rescue StandardError => e
          Rails.logger.error("Unexpected error in immunizations controller: #{e.message}")
          error = {
            title: 'Internal Server Error',
            detail: 'An unexpected error occurred while retrieving immunization records',
            code: '500',
            status: 500
          }
          render json: { errors: [error] }, status: :internal_server_error
        end
      end

      private

       def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn) 
      end
      
      def check_feature_toggle
        unless Flipper.enabled?(FEATURE_TOGGLE)
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