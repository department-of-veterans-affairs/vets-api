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
        recent_appointments = appointments_service.get_sorted_recent_appointments
        recent_ids = []

        if !recent_appointments.nil? && recent_appointments.present?
          recent_appointments.each do |appt|
            # if we don't have the information to lookup the location id, log 'unable to lookup' message
            recent_ids.push(appt.location_id) if location_id_available?(appt)
          end

          # remove duplicate facility ids
          recent_ids = recent_ids.uniq
        end

        # partition facilities using recency in preparation for sorting
        recent_facilities, other_facilities = facilities.partition { |facility| recent_ids.include?(facility[:id]) }

        # sort by recency
        recent_facilities = recent_facilities.sort_by { |facility| recent_ids.index(facility[:id]) }

        # sort by name
        other_facilities = other_facilities.sort_by { |facility| facility[:name] }

        recent_facilities.concat(other_facilities)
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def appointments_service
        @appointments_service ||=
          VAOS::V2::AppointmentsService.new(current_user)
      end

      def location_id_available?(appt)
        if appt.nil?
          Rails.logger.info('VAOS sort_by_recent_facilities - Appointment not found')
          return false
        end

        if appt.location_id.nil?
          Rails.logger.info('VAOS sort_by_recent_facilities - Appointment does not have location id')
          return false
        end

        true
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
