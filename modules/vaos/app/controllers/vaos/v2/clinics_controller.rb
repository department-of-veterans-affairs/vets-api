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

      def recent_facilities
        sorted_appointments = appointments_service.get_recent_sorted_appointments

        if sorted_appointments.blank?
          render json: { message: 'No appointments found' }, status: :not_found
          return
        end

        facility_ids = []

        sorted_appointments.each do |appt|
          # if we don't have the information to lookup the clinic, return 'unable to lookup' message
          unable_to_lookup_facility?(appt) ? log_unable_to_lookup_facility(appt) : facility_ids.push(appt.location_id)
        end

        # remove duplicate facility ids
        facility_ids = facility_ids.uniq
        sorted_facilities = []

        facility_ids.each do |facility_id|
          # get the facility details using the location id
          facility = mobile_facility_service.get_facility(facility_id)
          log_recent_facility_details(facility_id, facility)

          # if facility details are not returned, log 'not found' message
          facility.nil? ? log_no_facility_details_found(facility_id) : sorted_facilities.push(facility)
        end

        # Filter facilities
        sorted_facilities = filter_type_of_care_facilities(sorted_facilities)

        render json: FacilitiesSerializer.new(sorted_facilities)
      end

      private

      def appointments_service
        @appointments_service ||=
          VAOS::V2::AppointmentsService.new(current_user)
      end

      def filter_type_of_care_facilities(facilities)
        # Return facilities without filtering if no service id is provided
        service_id = params[:clinical_service_id]
        return facilities unless service_id

        # Retrieve facility scheduling configurations
        facility_ids = facilities.pluck(:id).to_csv(row_sep: nil)
        configurations = mobile_facility_service.get_scheduling_configurations(facility_ids)[:data]
        supported_facilities = []

        facilities.each do |facility|
          # Include facility in results if direct schedule or request is enabled for the given service
          configuration = configurations&.find { |config| config[:facility_id] == facility[:id] }
          service_configuration = configuration&.[](:services)&.find { |service| service[:id] == service_id }
          if service_configuration&.dig(:direct, :enabled) || service_configuration&.dig(:request, :enabled)
            supported_facilities.push(facility)
          end
        end

        supported_facilities
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

      def log_unable_to_lookup_facility(appt)
        message = ''
        if appt.nil?
          message = 'Appointment not found'
        elsif appt.location_id.nil?
          message = 'Appointment does not have location id'
        end

        Rails.logger.info('VAOS recent_facilities', message) if message.present?
      end

      def log_no_facility_details_found(location_id)
        Rails.logger.info 'VAOS recent_facilities', "No facility details found for location: #{location_id}"
      end

      def log_recent_facility_details(location_id, facility)
        Rails.logger.info("VAOS recent_facilities details for location: #{location_id} - #{facility.to_json}")
      end

      def unable_to_lookup_facility?(appt)
        appt.nil? || appt.location_id.nil?
      end

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def mobile_facility_service
        @mobile_facility_service ||=
          VAOS::V2::MobileFacilityService.new(current_user)
      end

      def location_id
        params.require(:location_id)
      end

      def recent_facilities_params
        params.permit(:clinical_service_id)
      end
    end
  end
end
