# frozen_string_literal: true

require 'mobile/v0/vaos_appointments/appointments_helper'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      after_action :clear_appointments_cache, only: %i[cancel create]

      def index
        use_cache = params[:useCache] || true
        start_date = params[:startDate] || appointments_cache_interface.latest_allowable_cache_start_date
        end_date = params[:endDate] || appointments_cache_interface.earliest_allowable_cache_end_date
        reverse_sort = !(params[:sort] =~ /-startDateUtc/).nil?

        validated_params = Mobile::V0::Contracts::Appointments.new.call(
          start_date:,
          end_date:,
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache:,
          reverse_sort:,
          included: params[:included],
          include: params[:include]
        )

        appointments = fetch_appointments(validated_params)
        appointments = filter_by_date_range(appointments, validated_params)
        page_appointments, page_meta_data = paginate(appointments, validated_params)

        render json: Mobile::V0::AppointmentSerializer.new(page_appointments, page_meta_data)
      end

      def cancel
        appointments_service.update_appointment(appointment_id, 'cancelled')

        head :no_content
      end

      def create
        Rails.logger.info('mobile appointments create', user_uuid: @current_user.uuid,
                                                        params: params.except(:description,
                                                                              :comment,
                                                                              :patient_instruction,
                                                                              :contact,
                                                                              :reason))

        new_appointment = appointments_helper.create_new_appointment(params)
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointment')
        render json: { data: serialized }, status: :created
      end

      private

      def appointments_service
        VAOS::V2::AppointmentsService.new(@current_user)
      end

      def appointment_id
        params.require(:id)
      end

      def clear_appointments_cache
        Mobile::V0::Appointment.clear_cache(@current_user)
      end

      def fetch_appointments(validated_params)
        appointments = appointments_cache_interface.fetch_appointments(
          user: @current_user, start_date: validated_params[:start_date], end_date: validated_params[:end_date],
          fetch_cache: validated_params[:use_cache]
        )

        appointments.filter! { |appt| appt.is_pending == false } unless include_pending?(validated_params)
        appointments.reverse! if validated_params[:reverse_sort]

        appointments
      end

      def filter_by_date_range(appointments, validated_params)
        appointments.filter do |appointment|
          appointment.start_date_utc.between?(
            validated_params[:start_date].beginning_of_day, validated_params[:end_date].end_of_day
          )
        end
      end

      def paginate(appointments, validated_params)
        Mobile::PaginationHelper.paginate(list: appointments, validated_params:)
      end

      def include_pending?(params)
        params[:include]&.include?('pending') || params[:included]&.include?('pending')
      end

      def appointments_helper
        @appointments_helper ||= Mobile::V0::VAOSAppointments::AppointmentsHelper.new(@current_user)
      end

      def appointments_cache_interface
        @appointments_cache_interface ||= Mobile::AppointmentsCacheInterface.new
      end
    end
  end
end
