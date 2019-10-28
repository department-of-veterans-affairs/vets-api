# frozen_string_literal: true
require_dependency 'vaos/application_controller'

module VAOS
  module V0
    class AppointmentsController < ApplicationController
      before_action :validate_params

      def index
        case params[:type]
        when 'cc'
          render json: appointment_service.get_cc_appointments(current_user, start_date, end_date)
        when 'va'
          render json: appointment_service.get_va_appointments(current_user, start_date, end_date)
        else
          raise Common::Exceptions::InvalidFieldValue.new('type', params[:type])
        end
      end

      private

      def appointment_service
        AppointmentService.new
      end

      def validate_params
        raise Common::Exceptions::ParameterMissing.new('type') if params[:type].blank?
        raise Common::Exceptions::ParameterMissing.new('start_date') if params[:start_date].blank?
        raise Common::Exceptions::ParameterMissing.new('end_date') if params[:end_date].blank?
      end

      def start_date
        Date.parse(params[:start_date])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
      end

      def end_date
        Date.parse(params[:end_date])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
      end
    end
  end
end
