# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'
require 'unique_user_events'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      include AppointmentAuthorization
      before_action :authorize_with_facilities
      UPCOMING_DAYS_LIMIT = 30
      TRAVEL_PAY_DAYS_LIMIT = 30

      def index
        staging_custom_error
        appointments, failures = fetch_appointments
        partial_errors = partial_errors(failures)
        status = get_response_status(failures)
        page_appointments, page_meta_data = paginate(appointments)

        build_page_metadata(page_meta_data, appointments, partial_errors)

        # Log unique user event for appointments accessed (with facility tracking for OH events)
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::APPOINTMENTS_ACCESSED,
          event_facility_ids: appointment_facility_ids(appointments)
        )

        render json: Mobile::V0::AppointmentSerializer.new(page_appointments, page_meta_data), status:
      end

      def cancel
        appointments_service.update_appointment(appointment_id, 'cancelled')

        head :no_content
      end

      def create
        new_appointment = appointment_creator.create_new_appointment(params)
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointment')
        render json: { data: serialized }, status: :created
      end

      private

      # Builds the page metadata including counts and limits
      #
      # @param page_meta_data [Hash] the pagination metadata hash
      # @param appointments [Array] the list of appointments
      # @param partial_errors [Hash, nil] the partial errors hash if present
      # @return [void] modifies page_meta_data in place
      def build_page_metadata(page_meta_data, appointments, partial_errors)
        page_meta_data[:meta].merge!(partial_errors) unless partial_errors.nil?
        page_meta_data[:meta].merge!(
          upcoming_appointments_count: upcoming_appointments_count(appointments),
          upcoming_days_limit: UPCOMING_DAYS_LIMIT
        )

        # Only attempt to count travel pay eligible appointments if include_claims flag is true
        if include_claims?
          page_meta_data[:meta].merge!(
            travel_pay_eligible_count: travel_pay_eligible_count(appointments),
            travel_pay_days_limit: TRAVEL_PAY_DAYS_LIMIT
          )
        end
      end

      def validated_params
        @validated_params ||= begin
          use_cache = params[:useCache] || true
          start_date = params[:startDate] || DateTime.now.utc.to_datetime
          end_date = params[:endDate] || 1.month.from_now.end_of_day.to_datetime
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

      def appointments_proxy
        Mobile::V2::Appointments::Proxy.new(@current_user)
      end

      def appointment_id
        params.require(:id)
      end

      def fetch_appointments
        appointments, failures = appointments_proxy.get_appointments(
          start_date: validated_params[:start_date],
          end_date: validated_params[:end_date],
          include_pending: true,
          include_claims: include_claims?
        )

        appointments.filter! { |appt| appt.is_pending == false } unless include_pending?
        appointments.reverse! if validated_params[:reverse_sort]

        [appointments, failures]
      rescue => e
        raise Common::Exceptions::BadGateway.new(detail: e.try(:errors).try(:first).try(:detail))
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

      # Checks how many appointments are eligible to file for travel pay
      def travel_pay_eligible_count(appointments)
        appointments.count do |appt|
          appt.travel_pay_eligible == true && # verify the appointment type is travel pay eligible
            appt.start_date_utc >= TRAVEL_PAY_DAYS_LIMIT.days.ago.utc && # verify it's within the last 30 days
            appt[:travelPayClaim][:claim].nil? # verify the appointment doesn't already have a travelPayClaim
        end
      end

      def appointment_creator
        @appointment_creator ||= Mobile::Shared::AppointmentCreator.new(@current_user)
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

      # Extract unique facility IDs (3-character) from user-visible appointments for OH event tracking
      # Only includes appointments that are pending or not cancelled (shown to users in the UI)
      # Note: facility_id may be a sta6aid (5-6 characters like "983GC") - we extract only the
      # 3-character facility ID prefix to match against TRACKED_FACILITY_IDS
      # Returns nil if mhv_oh_unique_user_metrics_logging_appt feature flag is disabled
      # @param appointments [Array<Mobile::V0::Appointment>] list of appointments
      # @return [Array<String>, nil] unique 3-character facility IDs or nil if none/disabled
      def appointment_facility_ids(appointments)
        return nil unless Flipper.enabled?(:mhv_oh_unique_user_metrics_logging_appt)

        cancelled_status = Mobile::V0::Adapters::VAOSV2Appointment::STATUSES[:cancelled]
        visible_appointments = appointments.select { |appt| appt.is_pending || appt.status != cancelled_status }
        station_ids = visible_appointments.filter_map { |appt| appt.facility_id&.[](0..2) }.uniq
        station_ids.presence
      end
    end
  end
end
