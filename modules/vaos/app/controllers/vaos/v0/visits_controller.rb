# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'common/exceptions'

module VAOS
  module V0
    class VisitsController < VAOS::V0::BaseController
      SCHEDULE_TYPES = %w[direct request].freeze

      def index
        response = systems_service.get_facility_visits(system_id, facility_id, type_of_care_id, schedule_type)
        render json: VAOS::V0::FacilityVisitSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def system_id
        params.require(:system_id)
      end

      def facility_id
        params.require(:facility_id)
      end

      def type_of_care_id
        params.require(:type_of_care_id)
      end

      def schedule_type
        raise_invalid_schedule_type unless SCHEDULE_TYPES.include?(params[:schedule_type])
        params.require(:schedule_type)
      end

      def raise_invalid_schedule_type
        raise Common::Exceptions::InvalidFieldValue.new('schedule_type', params[:schedule_type])
      end
    end
  end
end
# :nocov:
