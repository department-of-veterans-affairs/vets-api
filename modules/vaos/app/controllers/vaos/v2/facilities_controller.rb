# frozen_string_literal: true

module VAOS
  module V2
    class FacilitiesController < VAOS::BaseController
      def index
        response = mobile_facility_service.get_facilities(ids:,
                                                          schedulable:,
                                                          children:,
                                                          type:)
        response[:data] = sort_by_recent_facilities(response[:data]) if params[:sort_by] == 'recentLocations'
        render json: VAOS::V2::FacilitiesSerializer.new(response[:data], meta: response[:meta])
      end

      def show
        render json: VAOS::V2::FacilitiesSerializer.new(facility)
      end

      private

      def sort_by_recent_facilities(facilities)
        recent_appointments = appointments_service.get_recent_sorted_appointments
        recent_ids = []

        recent_appointments.each do |appt|
          # if we don't have the information to lookup the clinic, return 'unable to lookup' message
          unable_to_lookup_facility?(appt) ? log_unable_to_lookup_facility(appt) : recent_ids.push(appt.location_id)
        end

        # remove duplicate facility ids
        recent_ids = recent_ids.uniq

        # partition facilities using recency in preparation for sorting
        recent_facilities, other_facilities = facilities.partition { |facility| recent_ids.include?(facility[:id]) }

        # sort by recency
        recent_facilities.sort_by { |facility| recent_ids.index(facility[:id]) }

        # sort by name
        other_facilities.sort_by { |facility| facility[:name] }

        recent_facilities.concat(other_facilities)
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def appointments_service
        @appointments_service ||=
          VAOS::V2::AppointmentsService.new(current_user)
      end

      def unable_to_lookup_facility?(appt)
        appt.nil? || appt.location_id.nil?
      end

      def log_unable_to_lookup_facility(appt)
        message = ''
        if appt.nil?
          message = 'Appointment not found'
        elsif appt.location_id.nil?
          message = 'Appointment does not have location id'
        end

        Rails.logger.info('VAOS sort_by_recent_facilities', message) if message.present?
      end

      def facility
        @facility ||=
          mobile_facility_service.get_facility!(facility_id)
      end

      def facility_id
        params[:facility_id]
      end

      def ids
        ids = params.require(:ids)
        ids.is_a?(Array) ? ids.to_csv(row_sep: nil) : ids
      end

      def children
        params[:children]
      end

      def type
        params[:type]
      end

      def schedulable
        # We will always want to return 'true' for this param per github issue #59503
        # and PR vets-api#13087
        params[:schedulable] = true
      end
    end
  end
end
