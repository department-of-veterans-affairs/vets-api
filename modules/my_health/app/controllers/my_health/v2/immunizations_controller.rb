# frozen_string_literal: true

require 'lighthouse/veterans_health/client'
require 'lighthouse/veterans_health/models/immunization'
require 'lighthouse/veterans_health/serializers/immunization_serializer'
require 'unified_health_data/service'
require 'unified_health_data/serializers/immunization_serializer'
require 'common/client/errors'
require 'common/exceptions'
require 'unique_user_events'

module MyHealth
  module V2
    class ImmunizationsController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      service_tag 'mhv-medical-records'

      STATSD_KEY_PREFIX = 'api.my_health.immunizations'

      def index
        if uhd_enabled?
          immunizations = uhd_service.get_immunizations
          log_vaccines(immunizations.length)
          render json: UnifiedHealthData::ImmunizationSerializer.new(immunizations)
        else
          start_date = params[:start_date]
          end_date = params[:end_date]

          response = client.get_immunizations(start_date:, end_date:)
          immunizations = Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer
                          .from_fhir_bundle(response.body)

          log_vaccines(immunizations.length)
          render json: { data: immunizations }
        end
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'immunization records', api_type: uhd_enabled? ? 'SCDF' : 'FHIR')
      end

      def show
        id = params[:id]
        start_date = params[:start_date]
        end_date = params[:end_date]

        begin
          response = client.get_immunizations(start_date:, end_date:)
          immunization = response.body['entry'].find { |entry| entry['resource']['id'] == id }

          unless immunization
            render_error('Immunization Not Found',
                         'The requested immunization record was not found',
                         '404', 404, :not_found)
            return
          end

          return_value = Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer
                         .from_fhir(immunization['resource'])

          render json: { data: return_value }
        rescue Common::Client::Errors::ClientError,
               Common::Exceptions::BackendServiceException,
               StandardError => e
          handle_error(e, resource_name: 'immunization records', api_type: 'FHIR')
        end
      end

      private

      def uhd_enabled?
        Flipper.enabled?(:mhv_accelerated_delivery_vaccines_enabled, current_user)
      end

      def log_vaccines(vaccines_count)
        # Track the number of immunizations returned to the client
        StatsD.gauge("#{STATSD_KEY_PREFIX}.count", vaccines_count)

        # Log unique user events for immunizations/vaccines accessed
        UniqueUserEvents.log_events(
          user: current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_VACCINES_ACCESSED
          ]
        )
      end

      def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn)
      end

      def uhd_service
        @uhd_service ||= UnifiedHealthData::Service.new(current_user)
      end
    end
  end
end
