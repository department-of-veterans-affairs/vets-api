# frozen_string_literal: true

require 'unique_user_events'

module Mobile
  module V1
    class ImmunizationsController < ApplicationController
      service_tag 'mhv-medical-records'

      FUTURE_DATE = '3000-01-01'

      def index
        paginated_immunizations, meta = Mobile::PaginationHelper.paginate(list: immunizations,
                                                                          validated_params: pagination_params)

        # Log unique user events for immunizations/vaccines accessed
        UniqueUserEvents.log_events(
          user: @current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_VACCINES_ACCESSED
          ]
        )

        render json: Mobile::V0::ImmunizationSerializer.new(paginated_immunizations, meta)
      end

      private

      def immunizations_adapter
        Mobile::V0::Adapters::Immunizations.new
      end

      def service
        Mobile::V0::LighthouseHealth::Service.new(@current_user)
      end

      def pagination_params
        @pagination_params ||= Mobile::V0::Contracts::Immunizations.new.call(
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: params[:useCache] || true
        )
      end

      def immunizations
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
