# frozen_string_literal: true

module MHV
  module OhFacilitiesHelper
    class Service
      def initialize(user)
        super()
        @current_user = user
      end

      def user_at_pretransitioned_oh_facility?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          pretransitioned_oh_facilities.include?(facility.to_s)
        end
      end

      def user_facility_ready_for_info_alert?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          facilities_ready_for_info_alert.include?(facility.to_s)
        end
      end

      def user_facility_migrating_to_oh?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          facilities_migrating_to_oh.include?(facility.to_s)
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

      def facilities_migrating_to_oh
        @facilities_migrating_to_oh ||= parse_facility_setting(
          Settings.mhv.oh_facility_checks.facilities_migrating_to_oh
        )
      end

      def parse_facility_setting(value)
        return [] unless ActiveModel::Type::Boolean.new.cast(value)

        value.to_s.split(',').map(&:strip).compact_blank
      end
    end
  end
end
