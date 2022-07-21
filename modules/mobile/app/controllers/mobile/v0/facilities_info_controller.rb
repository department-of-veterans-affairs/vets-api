# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class FacilitiesInfoController < ApplicationController
      def index
        Rails.logger.info('Facilities info call start', { sort_method: params[:sort], user_uuid: @current_user.uuid })
        facility_ids = @current_user.va_treatment_facility_ids + @current_user.cerner_facility_ids
        facilities = appointments_proxy.fetch_facilities_from_ids(facility_ids, true)
        adapted_facilities = facilities.map do |facility|
          Mobile::V0::Adapters::FacilityInfo.new.parse(facility, @current_user, params)
        end
        sorted_facilities = sort(adapted_facilities, params[:sort])
        render json: Mobile::V0::FacilitiesInfoSerializer.new(@current_user.uuid, sorted_facilities)
      end

      private

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
      end

      def sort(facilities, sort_method)
        case sort_method
        when 'home', 'current'
          facilities.sort_by(&:miles)
        when 'alphabetical'
          facilities.sort_by(&:name)
        when 'appointments'
          sort_by_recent_appointment(facilities)
        else
          raise Common::Exceptions::ValidationErrorsBadRequest.new(
            detail: 'Invalid sort method', source: self.class.to_s, sort_method: sort_method
          )
        end
      end

      def sort_by_recent_appointment(facilities)
        facilities.sort_by(&:name) # entries not in recent appointments will be sorted alphabetically
        appointments = Mobile::V0::Appointment.get_cached(@current_user).sort_by(&:start_date_utc)
        if appointments.blank?
          raise Common::Exceptions::RecordNotFound.new(
            detail: 'Could not fetch user appointments', source: self.class.to_s
          )
        end
        recent_facilities = appointments.map(&:facility_id).uniq
        rf_hash = recent_facilities.each_with_index.to_h
        facilities.sort_by { |facility| [rf_hash[facility.id] || recent_facilities.size, facility.id] }
      end
    end
  end
end
