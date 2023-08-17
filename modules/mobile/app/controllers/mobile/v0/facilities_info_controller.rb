# frozen_string_literal: true

module Mobile
  module V0
    class FacilitiesInfoController < ApplicationController
      SORT_METHODS = %w[home current alphabetical appointments].freeze

      def index
        facility_ids = @current_user.va_treatment_facility_ids
        facilities = Mobile::FacilitiesHelper.fetch_facilities_from_ids(@current_user, facility_ids,
                                                                        include_children: false, schedulable: nil)
        adapted_facilities = facilities.map do |facility|
          Mobile::V0::Adapters::FacilityInfo.new.parse(facility, @current_user, params)
        end
        render json: Mobile::V0::FacilitiesInfoSerializer.new(@current_user.uuid, adapted_facilities)
      end

      def schedulable
        raise_invalid_sort_method_error unless SORT_METHODS.include?(params[:sort])

        facility_ids = @current_user.va_treatment_facility_ids + @current_user.cerner_facility_ids
        facilities = Mobile::FacilitiesHelper.fetch_facilities_from_ids(@current_user, facility_ids,
                                                                        include_children: true, schedulable: true)
        adapted_facilities = facilities.map do |facility|
          Mobile::V0::Adapters::FacilityInfo.new.parse(facility, @current_user, params)
        end
        sorted_facilities = sort(adapted_facilities, params[:sort])
        render json: Mobile::V0::FacilitiesInfoSerializer.new(@current_user.uuid, sorted_facilities)
      end

      private

      def sort(facilities, sort_method)
        case sort_method
        when 'home', 'current'
          facilities.sort_by(&:miles)
        when 'alphabetical'
          sort_by_name(facilities)
        when 'appointments'
          sort_by_recent_appointment(sort_by_name(facilities))
        else
          raise Common::Exceptions::BackendServiceException, 'unimplemented_sort_method'
        end
      end

      def sort_by_name(facilities)
        facilities.sort_by(&:name)
      end

      def sort_by_recent_appointment(facilities)
        appointments = Mobile::V0::Appointment.get_cached(@current_user)&.sort_by(&:start_date_utc)

        log_nil_cache if appointments.nil?
        return facilities if appointments.blank?

        appointment_facility_ids = appointments.map(&:facility_id).uniq

        appointment_facility_ids.map! do |facility_id|
          Mobile::V0::Appointment.convert_to_non_prod_id!(facility_id)
        end

        appointment_facilities_hash = appointment_facility_ids.each_with_index.to_h

        # appointment_facility_ids.size ensures any facility not found in appointment_facilities_hash is pushed to the
        # bottom of the array
        facilities.sort_by { |facility| appointment_facilities_hash[facility.id] || appointment_facility_ids.size }
      end

      def log_nil_cache
        Rails.logger.info('mobile facilities info appointments cache nil', user_uuid: @current_user.uuid)
      end

      def raise_invalid_sort_method_error
        raise Common::Exceptions::InvalidFieldValue.new('sort', params[:sort])
      end
    end
  end
end
