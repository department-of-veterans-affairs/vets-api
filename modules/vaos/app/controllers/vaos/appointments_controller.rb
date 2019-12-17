# frozen_string_literal: true

module VAOS
  class AppointmentsController < VAOS::BaseController
    before_action :validate_params, only: :index

    def index
      render json: each_serializer.new(appointments[:data], meta: appointments[:meta])
    end

    # not sure whether to use standard update action here, seeing as appointments don't have legitimate id.
    def cancel
      appointment_service.put_cancel_appointment(cancel_params)
      head :no_content
    end

    private

    def cancel_params
      params.permit(:appointment_time, :clinic_id, :cancel_reason, :cancel_code, :remarks, :clinic_name)
    end

    def appointment_service
      VAOS::AppointmentService.for_user(current_user)
    end

    def appointments
      @appointments ||=
        appointment_service.get_appointments(type, start_date, end_date, pagination_params)
    end

    def each_serializer
      "VAOS::#{params[:type].upcase}AppointmentsSerializer".constantize
    end

    def validate_params
      raise Common::Exceptions::ParameterMissing, 'type' if type.blank?
      raise Common::Exceptions::InvalidFieldValue.new('type', type) unless %w[va cc].include?(type)
      raise Common::Exceptions::ParameterMissing, 'start_date' if params[:start_date].blank?
      raise Common::Exceptions::ParameterMissing, 'end_date' if params[:end_date].blank?
    end

    def type
      params[:type]
    end

    def start_date
      DateTime.parse(params[:start_date]).in_time_zone
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
    end

    def end_date
      DateTime.parse(params[:end_date]).in_time_zone
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
    end
  end
end
