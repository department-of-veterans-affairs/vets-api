# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        appointments, errors = appointments_proxy.get_appointments(start_date, end_date)

        options = {
          meta: {
            errors: errors.size.positive? ? errors : nil
          }
        }

        render json: Mobile::V0::AppointmentSerializer.new(appointments, options)
      end

      private

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
      end

      def start_date
        DateTime.parse(params[:startDate])
      rescue ArgumentError, TypeError
        raise Common::Exceptions::InvalidFieldValue.new('startDate', params[:startDate])
      end

      def end_date
        DateTime.parse(params[:endDate])
      rescue ArgumentError, TypeError
        raise Common::Exceptions::InvalidFieldValue.new('endDate', params[:endDate])
      end
    end
  end
end
