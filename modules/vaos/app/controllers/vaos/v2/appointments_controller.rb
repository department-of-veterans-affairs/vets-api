# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::V0::BaseController
      def index
        appointments
        merge_clinic_names(appointments[:data])
        merge_facility_address(appointments[:data])
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointments[:data], 'appointments')
        render json: { data: serialized, meta: appointments[:meta] }
      end

      def show
        appointment
        unless appointment[:clinic].nil?
          appointment[:station_name] = get_clinic_name(appointment[:location_id], appointment[:clinic])
        end

        unless appointment[:location_id].nil?
          appointment[:physical_address] = get_facility_address(appointment[:location_id])
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointment, 'appointments')
        render json: { data: serialized }
      end

      def create
        new_appointment
        unless new_appointment[:clinic].nil?
          new_appointment[:station_name] = get_clinic_name(new_appointment[:location_id], new_appointment[:clinic])
        end

        unless new_appointment[:location_id].nil?
          new_appointment[:physical_address] = get_facility_address(new_appointment[:location_id])
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointments')
        render json: { data: serialized }, status: :created
      end

      def update
        updated_appointment
        unless updated_appointment[:clinic].nil?
          updated_appointment[:station_name] =
            get_clinic_name(updated_appointment[:location_id], updated_appointment[:clinic])
        end

        unless updated_appointment[:location_id].nil?
          updated_appointment[:physical_address] = get_facility_address(updated_appointment[:location_id])
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(updated_appointment, 'appointments')
        render json: { data: serialized }
      end

      private

      def appointments_service
        VAOS::V2::AppointmentsService.new(current_user)
      end

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, statuses, pagination_params)
      end

      def appointment
        @appointment ||=
          appointments_service.get_appointment(appointment_id)
      end

      def new_appointment
        @new_appointment ||=
          appointments_service.post_appointment(create_params)
      end

      def updated_appointment
        @updated_appointment ||=
          appointments_service.update_appointment(update_appt_id, status_update)
      end

      def merge_clinic_names(appointments)
        cached_clinic_names = {}
        appointments.each do |appt|
          unless appt[:clinic].nil?
            unless cached_clinic_names[:clinic]
              clinic_name = get_clinic_name(appt[:location_id], appt[:clinic])
              cached_clinic_names[appt[:clinic]] = clinic_name
            end

            appt[:station_name] = cached_clinic_names[appt[:clinic]] if cached_clinic_names[appt[:clinic]]
          end
        end
      end

      def merge_facility_address(appointments)
        cached_fac_addr = {}
        appointments.each do |appt|
          unless appt[:location_id].nil?
            unless cached_fac_addr[:location_id]
              facility_address = get_facility_address(appt[:location_id])
              cached_fac_addr[appt[:location_id]] = facility_address
            end

            appt[:physical_address] = cached_fac_addr[appt[:location_id]] if cached_fac_addr[appt[:location_id]]
          end
        end
      end

      def get_clinic_name(location_id, clinic_id)
        clinics = systems_service.get_facility_clinics(location_id: location_id, clinic_ids: clinic_id)
        clinics.first[:station_name] unless clinics.empty?
      rescue Common::Exceptions::BackendServiceException
        Rails.logger.error(
          "Error fetching clinic #{clinic_id} for location #{location_id}",
          clinic_id: clinic_id,
          location_id: location_id
        )
      end

      def get_facility_address(location_id)
        facility = mobile_facility_service.get_facility(location_id)
        facility&.physical_address
      rescue Common::Exceptions::BackendServiceException
        Rails.logger.error(
          "Error fetching facility details for location_id #{location_id}",
          location_id: location_id
        )
      end

      def update_appt_id
        params.require(:id)
      end

      def status_update
        params.require(:status)
      end

      def appointment_params
        params.require(:start)
        params.require(:end)
        params.permit(:start, :end)
      end

      def create_params
        params.permit(:kind,
                      :status,
                      :location_id,
                      :clinic,
                      :reason,
                      :service_type,
                      :preferred_language,
                      slot: %i[id start end],
                      contact: [telecom: %i[type value]],
                      requested_periods: %i[start end],
                      practitioner_ids: %i[system value])
      end

      def start_date
        DateTime.parse(appointment_params[:start]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start', params[:start])
      end

      def end_date
        DateTime.parse(appointment_params[:end]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end', params[:end])
      end

      def statuses
        s = params[:statuses]
        s.is_a?(Array) ? s.to_csv(row_sep: nil) : s
      end

      def appointment_id
        params[:appointment_id]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('appointment_id', params[:appointment_id])
      end
    end
  end
end
