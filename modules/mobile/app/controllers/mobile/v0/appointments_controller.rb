# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        responses = appointments_service.get_appointments(start_date, end_date)
        binding.pry
        va_appointments, facility_ids = va_adapter.parse(responses[:va].body)
        cc_appointments = cc_adapter.parse(responses[:cc].body)
        
        if va_appointments.size > 0
          va_appointments = appointments_with_facilities(facility_ids)
        end
        
        appointments = (va_appointments + cc_appointments).sort_by(&:start_date)
        render json: Mobile::V0::AppointmentSerializer.new(appointments)
      end
      
      private
      
      def appointments_with_facilities(facility_ids)
        facilities = facilities_service.get_facilities(ids: facility_ids.to_a.map { |id| "vha_#{id}" })
      end
      
      def appointments_service
        Mobile::V0::Appointments::Service.new(@current_user)
      end
      
      def facilities_service
        Lighthouse::Facilities::Client.new
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
