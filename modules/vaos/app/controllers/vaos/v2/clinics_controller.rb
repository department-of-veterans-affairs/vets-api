# frozen_string_literal: true

module VAOS
  module V2
    class ClinicsController < VAOS::BaseController
      CLINIC_KEY = 'Clinic'

      def index
        response = systems_service.get_facility_clinics(location_id:,
                                                        clinic_ids: params[:clinic_ids],
                                                        clinical_service: params[:clinical_service],
                                                        page_size: params[:page_size],
                                                        page_number: params[:page_number])
        render json: VAOS::V2::ClinicsSerializer.new(response)
      end

      def last_visited_clinic
        # get the last clinic appointment from the appointments service
        latest_appointment = appointments_service.get_most_recent_visited_clinic_appointment

        # if we don't have the information to lookup the clinic, return 404
        if unable_to_lookup_clinic?(latest_appointment)
          log_unable_to_lookup_clinic(latest_appointment)
          render json: { message: 'Unable to lookup latest clinic.' }, status: :not_found
          return
        end

        # get the clinic details using the station id and clinic id
        station_id = latest_appointment.location_id
        clinic_id = latest_appointment.clinic
        clinic = mobile_facility_service.get_clinic_with_cache(station_id:, clinic_id:)

        # if clinic details are not returned, return 404
        if clinic.nil?
          log_no_clinic_details_found(station_id, clinic_id)
          render json: { message: 'No clinic details found' }, status: :not_found
          return
        end

        # return the clinic details
        render json: VAOS::V2::ClinicsSerializer.new(clinic)
      end

      def recent_clinics
        sorted_clinics = []
        sorted_appointments = appointments_service.get_recent_sorted_clinic_appointments

        if sorted_appointments.blank?
          render json: { message: 'No appointments found' }, status: :not_found
          return
        end
        sorted_appointments.each do |appt|
          # if we don't have the information to lookup the clinic, return 'unable to lookup' message
          if unable_to_lookup_clinic?(appt)
            log_unable_to_lookup_clinic(appt)
          else
            # get the clinic details using the station id and clinic id
            location_id = appt.location_id
            clinic_ids = appt.clinic
            clinic = systems_service.get_facility_clinics(location_id:, clinic_ids:)&.first

            # if clinic details are not returned, log 'not found' message
            clinic.nil? ? log_no_clinic_details_found(location_id, clinic_ids) : sorted_clinics.push(clinic)
          end
        end

        render json: VAOS::V2::ClinicsSerializer.new(sorted_clinics)
      end

      private

      def appointments_service
        @appointments_service ||=
          VAOS::V2::AppointmentsService.new(current_user)
      end

      def log_unable_to_lookup_clinic(appt)
        message = ''
        if appt.nil?
          message = 'Appointment not found'
        elsif appt.location_id.nil?
          message = 'Appointment does not have location id'
        elsif appt.clinic.nil?
          message = 'Appointment does not have clinic id'
        end

        Rails.logger.info('VAOS last_visited_clinic', message) if message.present?
      end

      def log_no_clinic_details_found(station_id, clinic_id)
        Rails.logger.info 'VAOS last_visited_clinic', "No clinic details found for station: #{station_id} " \
                                                      "and clinic: #{clinic_id}"
      end

      def unable_to_lookup_clinic?(appt)
        appt.nil? || appt.location_id.nil? || appt.clinic.nil?
      end

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def location_id
        params.require(:location_id)
      end
    end
  end
end
