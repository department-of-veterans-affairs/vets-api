# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      include AppointmentAuthorization
      before_action :authorize_with_facilities
      UPCOMING_DAYS_LIMIT = 30

      after_action :clear_appointments_cache, only: %i[cancel create]

      def index
        staging_custom_error
        appointments, failures = fetch_appointments
        appointments = filter_by_date_range(appointments)
        partial_errors = partial_errors(failures)
        status = get_response_status(failures)
        page_appointments, page_meta_data = paginate(appointments)
        page_meta_data[:meta].merge!(partial_errors) unless partial_errors.nil?
        page_meta_data[:meta].merge!(
          upcoming_appointments_count: upcoming_appointments_count(appointments),
          upcoming_days_limit: UPCOMING_DAYS_LIMIT
        )

        render json: Mobile::V0::AppointmentSerializer.new(page_appointments, page_meta_data), status:
      end

      def cancel
        appointments_service.update_appointment(appointment_id, 'cancelled')

        head :no_content
      end

      def create
        new_appointment = appointments_helper.create_new_appointment(params)
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointment')
        render json: { data: serialized }, status: :created
      end

      private

      def validated_params
        @validated_params ||= begin
          use_cache = params[:useCache] || true
          start_date = params[:startDate] || appointments_cache_interface.latest_allowable_cache_start_date
          end_date = params[:endDate] || appointments_cache_interface.earliest_allowable_cache_end_date
          reverse_sort = !(params[:sort] =~ /-startDateUtc/).nil?

          Mobile::V0::Contracts::Appointments.new.call(
            start_date:,
            end_date:,
            page_number: params.dig(:page, :number),
            page_size: params.dig(:page, :size),
            use_cache:,
            reverse_sort:,
            included: params[:included],
            include: params[:include]
          )
        end
      end

      def appointments_service
        VAOS::V2::AppointmentsService.new(@current_user)
      end

      def appointment_id
        params.require(:id)
      end

      def clear_appointments_cache
        Mobile::V0::Appointment.clear_cache(@current_user)
      end

      def fetch_appointments
        appointments, failures = appointments_cache_interface.fetch_appointments(
          user: @current_user, start_date: validated_params[:start_date], end_date: validated_params[:end_date],
          fetch_cache: validated_params[:use_cache], include_claims: include_claims?
        )

        appointments.filter! { |appt| appt.is_pending == false } unless include_pending?
        appointments.reverse! if validated_params[:reverse_sort]

        [appointments, failures]
      end

      # Data is aggregated from multiple servers and if any of the servers doesnt respond, we receive failures
      # The mobile app shows the user a banner when there are partial appointment errors.
      # The mobile app does not distinguish between VA and CC errors so we are only indicating that there are errors
      # If we ever want to distinguish be VA and CC errors, it will require coordination with the front-end team
      def partial_errors(failures)
        if failures.present?
          {
            errors: [{ source: 'VA Service' }]
          }
        end
      end

      def get_response_status(failures)
        failures.present? ? :multi_status : :ok
      end

      def filter_by_date_range(appointments)
        appointments.filter do |appointment|
          appointment.start_date_utc.between?(
            validated_params[:start_date].beginning_of_day, validated_params[:end_date].end_of_day
          )
        end
      end

      def paginate(appointments)
        Mobile::PaginationHelper.paginate(list: appointments, validated_params:)
      end

      def include_pending?
        validated_params[:include]&.include?('pending') || validated_params[:included]&.include?('pending')
      end

      def include_claims?
        validated_params[:include]&.include?('travel_pay_claims') ||
          validated_params[:included]&.include?('travel_pay_claims')
      end

      def upcoming_appointments_count(appointments)
        appointments.count do |appt|
          appt.is_pending == false && appt.status == 'BOOKED' && appt.start_date_utc > Time.now.utc &&
            appt.start_date_utc <= UPCOMING_DAYS_LIMIT.days.from_now.end_of_day.utc
        end
      end

      def appointments_helper
        @appointments_helper ||= Mobile::AppointmentsHelper.new(@current_user)
      end

      def appointments_cache_interface
        @appointments_cache_interface ||= Mobile::AppointmentsCacheInterface.new
      end

      def staging_custom_error
        if Settings.vsp_environment != 'production' && @current_user.email == 'vets.gov.user+141@gmail.com'
          raise Mobile::V0::Exceptions::CustomErrors.new(
            title: 'Custom error title',
            body: 'Custom error body. \n This explains to the user the details of the ongoing issue.',
            source: 'VAOS',
            telephone: '999-999-9999',
            refreshable: true
          )
        end
      end
    end
  end
end
