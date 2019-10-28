# frozen_string_literal: true
require_dependency 'vaos/application_controller'

module VAOS
  module V0
    class AppointmentsController < ApplicationController
      def index
        response = if params[:type] == 'cc'
          va_mobile_service.get_cc_appointments(current_user, date_range)
        else
          va_mobile_service.get_va_appointments(current_user, date_range)
        end
        render json: VAOS::AppointmentSerializer.new(response)
      end

      private

      def date_range
        raise Common::Exceptions::ParameterMissing, 'start_date' if params[:start_date].blank?
        raise Common::Exceptions::ParameterMissing, 'end_date' if params[:end_date].blank?
        { start_date: params[:start_date], end_date: params[:end_date] }
      end
    end
  end
end
