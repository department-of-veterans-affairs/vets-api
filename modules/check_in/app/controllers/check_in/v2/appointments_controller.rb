# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[index]
      after_action :after_logger, only: %i[index]

      def index
        check_in_session

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        appointments
        # find the facility and clinic IDs from all appointments
        # make a call to facilities and clinic endpoints
        # combine the appointments payload with facilities and clinics data

        merge_facilities(appointments[:data])

        serializer = VAOS::AppointmentSerializer.new(appt_struct_data)

        render json: serializer.serializable_hash.to_json, status: :ok
      end

      def permitted_params
        params.permit(:start, :end, :_include)
      end

      private

      def appt_struct_data
        struct = JSON.parse(appointments.to_json, object_class: OpenStruct)
        struct.data
      end

      def merge_facilities(appointments)
        appointments.each do |appt|
          unless appt[:locationId].nil?
            appt[:facility] = facility_service.get_facility_with_cache(facility_id: appt[:locationId])
          end
        end
      end

      def check_in_session
        @check_in_session ||= CheckIn::V2::Session.build(data: { uuid: params[:session_id] }, jwt: low_auth_token)
      end

      def appointments
        @appointments ||= appointments_service.get_appointments(start_date, end_date)
      end

      def appointments_service
        @appointments_service ||= CheckIn::VAOS::AppointmentService.new(check_in_session:)
      end

      def facility_service
        @facility_service ||= CheckIn::VAOS::FacilityService.new
      end

      def start_date
        DateTime.parse(permitted_params[:start]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start', params[:start])
      end

      def end_date
        DateTime.parse(permitted_params[:end]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end', params[:end])
      end

      def authorize
        routing_error unless Flipper.enabled?(:check_in_experience_upcoming_appointments_enabled)
      end
    end
  end
end
