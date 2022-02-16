# frozen_string_literal: true

require 'lighthouse/facilities/client'

module Mobile
  module V0
    module Appointments
      class Proxy
        CANCEL_CODE = 'PC'
        CANCEL_ASSIGNING_AUTHORITY = 'ICN'
        UNABLE_TO_KEEP_APPOINTMENT = '5'
        VALID_CANCEL_CODES = %w[4 5 6].freeze

        def initialize(user)
          @user = user
        end

        def get_appointments(start_date:, end_date:)
          legacy_fetch_appointments(start_date, end_date)
        end

        def put_cancel_appointment(params)
          facility_id = Mobile::V0::Appointment.toggle_non_prod_id!(params[:facilityId])

          cancel_reasons = get_facility_cancel_reasons(facility_id)
          cancel_reason = extract_valid_reason(cancel_reasons.map(&:number))

          raise Common::Exceptions::BackendServiceException, 'MOBL_404_cancel_reason_not_found' if cancel_reason.nil?

          put_params = {
            appointment_time: params[:appointmentTime].strftime('%m/%d/%Y %H:%M:%S'),
            clinic_id: params[:clinicId],
            cancel_reason: cancel_reason,
            cancel_code: CANCEL_CODE,
            clinic_name: params['healthcareService'],
            facility_id: facility_id,
            remarks: ''
          }

          vaos_appointments_service.put_cancel_appointment(put_params)
        rescue Common::Exceptions::BackendServiceException => e
          handle_cancel_error(e, params)
        end

        private

        def legacy_fetch_appointments(start_date, end_date)
          va_response, cc_response = Parallel.map(
            [
              fetch_va_appointments(start_date, end_date),
              fetch_cc_appointments(start_date, end_date)
            ], in_threads: 2, &:call
          )

          errors = [va_response[:error], cc_response[:error]].compact

          raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' if errors.size.positive?

          va_appointments = va_appointments_adapter.parse(va_response[:response].body)
          cc_appointments = cc_appointments_adapter.parse(cc_response[:response].body)

          facilities = fetch_facilities(va_appointments)
          va_appointments = backfill_appointments_with_facilities(va_appointments, facilities)

          # There's currently a bug in the underlying Community Care service
          # where date ranges are not being respected
          cc_appointments.select! do |appointment|
            appointment.start_date_utc.between?(start_date, end_date)
          end

          (va_appointments + cc_appointments).sort_by(&:start_date_utc)
        end

        def fetch_facilities(appointments)
          facility_ids = appointments.collect { |appt| appt.sta6aid || appt.facility_id }.uniq
          facility_ids.each do |facility_id|
            Rails.logger.info('metric.mobile.appointment.facility', facility_id: facility_id)
          end
          Mobile::FacilitiesHelper.get_facilities(facility_ids)
        end

        def backfill_appointments_with_facilities(appointments, facilities)
          va_facilities_adapter.map_appointments_to_facilities(appointments, facilities)
        end

        def extract_valid_reason(cancel_reason_codes)
          valid_codes = cancel_reason_codes & VALID_CANCEL_CODES
          return nil if valid_codes.empty?
          return UNABLE_TO_KEEP_APPOINTMENT if unable_to_keep_appointment?(valid_codes)

          valid_codes.first
        end

        def get_facility_cancel_reasons(facility_id)
          vaos_systems_service.get_cancel_reasons(facility_id)
        end

        def unable_to_keep_appointment?(valid_codes)
          valid_codes.include? UNABLE_TO_KEEP_APPOINTMENT
        end

        def handle_cancel_error(e, params)
          if e.original_status == 409
            Rails.logger.info(
              'mobile cancel appointment facility not supported',
              clinic_id: params[:clinicId],
              facility_id: params[:facilityId]
            )
            raise Common::Exceptions::BackendServiceException, 'MOBL_409_facility_not_supported'
          end

          raise e
        end

        def appointments_service
          Mobile::V0::Appointments::Service.new(@user)
        end

        def fetch_va_appointments(start_date, end_date)
          lambda {
            appointments_service.fetch_va_appointments(start_date, end_date)
          }
        end

        def fetch_cc_appointments(start_date, end_date)
          lambda {
            appointments_service.fetch_cc_appointments(start_date, end_date)
          }
        end

        def vaos_appointments_service
          VAOS::AppointmentService.new(@user)
        end

        def vaos_systems_service
          VAOS::SystemsService.new(@user)
        end

        def va_appointments_adapter
          Mobile::V0::Adapters::VAAppointments.new
        end

        def va_facilities_adapter
          Mobile::V0::Adapters::VAFacilities.new
        end

        def cc_appointments_adapter
          Mobile::V0::Adapters::CommunityCareAppointments.new
        end
      end
    end
  end
end
