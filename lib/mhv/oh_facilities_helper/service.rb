# frozen_string_literal: true

module MHV
  module OhFacilitiesHelper
    class Service
      def initialize(user)
        super()
        @current_user = user
      end

      def user_at_pretransitioned_oh_facility?
        @current_user.va_treatment_facility_ids.any? do |facility|
          pretransitioned_oh_facilities.include?(facility.to_s)
        end
      end

      def user_facility_ready_for_info_alert?
        @current_user.va_treatment_facility_ids.any? do |facility|
          facilities_ready_for_info_alert.include?(facility.to_s)
        end
      end

      private

      def pretransitioned_oh_facilities
        @pretransitioned_oh_facilities ||= Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities.split(',').map(&:strip)
      end

      def facilities_ready_for_info_alert
        @facilities_ready_for_info_alert ||= Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert.split(',').map(&:strip)
      end
    end
  end
end
