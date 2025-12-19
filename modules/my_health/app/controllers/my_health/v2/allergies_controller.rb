# frozen_string_literal: true

require 'unified_health_data/service'
require 'unified_health_data/serializers/allergy_serializer'
require 'unique_user_events'

module MyHealth
  module V2
    class AllergiesController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        allergies = sort_records(service.get_allergies, params[:sort])
        serialized_allergies = UnifiedHealthData::AllergySerializer.new(allergies)

        # Log unique user events for allergies accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ALLERGIES_ACCESSED
          ]
        )

        render json: serialized_allergies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'allergies', api_type: 'FHIR')
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
        handle_error(e, resource_name: 'allergies', api_type: 'FHIR')
      end

      private

      def service
        @service ||= UnifiedHealthData::Service.new(@current_user)
      end
    end
  end
end
