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
        log_clinic_names(response)
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

      def log_clinic_names(clinic_data)
        clinic_data.each do |clinic|
          clinic_names = { CLINIC_KEY => clinic_name_metrics(clinic) }
          Rails.logger.info('Clinic names returned', clinic_names.to_json) unless clinic_names.empty?
        end
      end

      def clinic_name_metrics(clinic)
        {
          stationId: clinic.station_id,
          serviceName: clinic.service_name
        }
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
