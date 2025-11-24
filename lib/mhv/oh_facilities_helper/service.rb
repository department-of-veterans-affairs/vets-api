# frozen_string_literal: true

module MHV
  module OhFacilitiesHelper
    class Service < Common::Client::Base
      def initialize(user)
        super()
        @current_user = user
      end

      def user_at_pretransitioned_oh_facility?
        @current_user.va_treatment_facility_ids.each do |facility|
          return true if Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities.include?(facility.to_s)
        end
        false
      end

      def user_facility_ready_for_info_alert?
        @current_user.va_treatment_facility_ids.each do |facility|
          return true if Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert.include?(facility.to_s)
        end
        false
      end
    end
  end
end
