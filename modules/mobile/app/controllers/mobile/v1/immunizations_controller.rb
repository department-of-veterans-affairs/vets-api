# frozen_string_literal: true

require 'unique_user_events'
require 'unified_health_data/service'
require 'unified_health_data/serializers/immunization_serializer'

module Mobile
  module V1
    class ImmunizationsController < ApplicationController
      include SortableRecords
      service_tag 'mhv-medical-records'

      FUTURE_DATE = '3000-01-01'

      def index
        immunizations = uhd_enabled? ? sort_records(uhd_service.get_immunizations) : lh_immunizations

        # Log unique user events for immunizations/vaccines accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_VACCINES_ACCESSED
          ]
        )

        serialized_immunizations = if uhd_enabled?
                                     UnifiedHealthData::ImmunizationSerializer.new(
                                       immunizations
                                     )
                                   else
                                     paginated_immunizations, meta =
                                       Mobile::PaginationHelper.paginate(list: immunizations,
                                                                         validated_params: pagination_params)
                                     Mobile::V0::ImmunizationSerializer.new(paginated_immunizations, meta)
                                   end
        render json: serialized_immunizations
      end

      private

      def uhd_enabled?
        Flipper.enabled?(:mhv_accelerated_delivery_vaccines_enabled, current_user)
      end

      def immunizations_adapter
        Mobile::V0::Adapters::Immunizations.new
      end

      def service
        Mobile::V0::LighthouseHealth::Service.new(@current_user)
      end

      def uhd_service
        @uhd_service ||= UnifiedHealthData::Service.new(@current_user)
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Immunizations.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: params[:useCache] || true
        )
      end

      def lh_immunizations
        immunizations = Mobile::V0::Immunization.get_cached(@current_user) if pagination_params[:use_cache]

        unless immunizations
          immunizations = immunizations_adapter.parse(service.get_immunizations)
          Mobile::V0::Immunization.set_cached(@current_user, immunizations)
        end

        # Handle nil dates by sorting at the end of the list
        immunizations.sort_by { |item| item.date || FUTURE_DATE }
      end
    end
  end
end
