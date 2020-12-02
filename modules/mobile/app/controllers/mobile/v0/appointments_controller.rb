# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        responses = service.get_appointments(start_date, end_date)
        va_appointments = va_adapter.parse(responses[:va])
        cc_appointments = cc_adapter.parse(responses[:cc])
      end
      
      private
      
      def service
        Mobile::V0::Appointments::Service.new(@current_user)
      end
      
      def va_adapter
        Mobile::V0::Adapters::VAAppointments.new
      end
      
      def cc_adapter
        Mobile::V0::Adapters::CommunityCareAppointments.new
      end

      def start_date
        DateTime.parse(params[:start_date])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
      end

      def end_date
        DateTime.parse(params[:end_date])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
      end
    end
  end
end
