# frozen_string_literal: true

module MHV
  module OhFacilitiesHelper
    class Service
      def initialize(user)
        super()
        @current_user = user
      end

      OH_FEATURE_TOGGLES = [
        # List of OH feature toggles to check
        :mhv_accelerated_delivery_allergies_enabled,
        :mhv_accelerated_delivery_care_notes_enabled,
        :mhv_accelerated_delivery_conditions_enabled,
        :mhv_accelerated_delivery_labs_and_tests_enabled,
        :mhv_accelerated_delivery_vaccines_enabled,
        :mhv_accelerated_delivery_vital_signs_enabled,
        :mhv_secure_messaging_cerner_pilot,
        :mhv_medications_cerner_pilot
      ].freeze

      def user_at_pretransitioned_oh_facility?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          pretransitioned_oh_facilities.include?(facility.to_s)
        end
      end

      def user_facility_ready_for_info_alert?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          facilities_ready_for_info_alert.include?(facility.to_s) && feature_toggle_enabled?
        end
      end

      private

      def pretransitioned_oh_facilities
        @pretransitioned_oh_facilities ||= parse_facility_setting(
          Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities
        )
      end

      def facilities_ready_for_info_alert
        @facilities_ready_for_info_alert ||= parse_facility_setting(
          Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert
        )
      end

      def parse_facility_setting(value)
        return [] unless ActiveModel::Type::Boolean.new.cast(value)

        value.to_s.split(',').map(&:strip).compact_blank
      end

      def feature_toggle_enabled?
        ActiveModel::Type::Boolean.new.cast(
          # Check the main "power switch" toggle
          Flipper.enabled?(:mhv_accelerated_delivery_enabled, @current_user) &&
            # check list of all OH feature toggles
            # if any are enabled, return true
            OH_FEATURE_TOGGLES.any? { |toggle| Flipper.enabled?(toggle, @current_user) }
        )
      rescue
        false
      end
    end
  end
end
