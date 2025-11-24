# frozen_string_literal: true

module MHV
  module OhFacilitiesHelper
    class Service < Common::Client::Base
      def user_at_pretransitioned_oh_facility?
        # Settings.oh_facility_checks.pretransitioned_oh_facilities
        # check all @current_user facilities and return true if any of them are present in above list
      end

      def user_facility_ready_for_info_alert?
        # Settings.oh_facility_checks.facilities_ready_for_info_alert
        # check all @current_user facilities and return true if any of them are present in above list
      end
    end
  end
end
# frozen_string_literal: true
