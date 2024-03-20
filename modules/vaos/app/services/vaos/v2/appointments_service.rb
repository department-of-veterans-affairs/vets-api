# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'
require 'memoist'

module VAOS
  module V2
    class AppointmentsService < VAOS::SessionService
      extend Memoist

      DIRECT_SCHEDULE_ERROR_KEY = 'DirectScheduleError'
      VAOS_SERVICE_DATA_KEY = 'VAOSServiceTypesAndCategory'
      FACILITY_ERROR_MSG = 'Error fetching facility details'
      AVS_ERROR_MESSAGE = 'Error retrieving AVS link'
      AVS_APPT_TEST_ID = '192308'

      AVS_FLIPPER = :va_online_scheduling_after_visit_summary
      CANCEL_EXCLUSION = :va_online_scheduling_cancellation_exclusion
      ORACLE_HEALTH_CANCELLATIONS = :va_online_scheduling_enable_OH_cancellations

      def get_appointments(start_date, end_date, statuses = nil, pagination_params = {})
        params = date_params(start_date, end_date)
                 .merge(page_params(pagination_params))
                 .merge(status_params(statuses))
                 .compact

        with_monitoring do
          response = perform(:get, appointments_base_path, params, headers)
          SchemaContract::ValidationInitiator.call(user:, response:, contract_name: 'appointments_index')
          response.body[:data].each do |appt|
            # for Lovell appointments set cancellable to false per GH#75512
            set_cancellable_false(appt) if lovell_appointment?(appt) && Flipper.enabled?(CANCEL_EXCLUSION, user)

            # for CnP and covid appointments set cancellable to false per GH#57824, GH#58690
            set_cancellable_false(appt) if cnp?(appt) || covid?(appt)

            # remove service type(s) for non-medical non-CnP appointments per GH#56197
            remove_service_type(appt) unless medical?(appt) || cnp?(appt) || no_service_cat?(appt)

            # set requestedPeriods to nil if the appointment is a booked cerner appointment per GH#62912
            appt[:requested_periods] = nil if booked?(appt) && cerner?(appt)

            convert_appointment_time(appt)

            fetch_avs_and_update_appt_body(appt) if avs_applicable?(appt) && Flipper.enabled?(AVS_FLIPPER, user)
          end
          {
            data: deserialized_appointments(response.body[:data]),
            meta: pagination(pagination_params).merge(partial_errors(response))
          }
        end
      end

      def get_appointment(appointment_id)
        params = {}
        with_monitoring do
          response = perform(:get, get_appointment_base_path(appointment_id), params, headers)
          convert_appointment_time(response.body[:data])

          # for Lovell appointments set cancellable to false per GH#75512
          if lovell_appointment?(response.body[:data]) && Flipper.enabled?(CANCEL_EXCLUSION, user)
            set_cancellable_false(response.body[:data])
          end

          # for CnP and covid appointments set cancellable to false per GH#57824, GH#58690
          set_cancellable_false(response.body[:data]) if cnp?(response.body[:data]) || covid?(response.body[:data])

          # remove service type(s) for non-medical non-CnP appointments per GH#56197
          unless medical?(response.body[:data]) || cnp?(response.body[:data]) || no_service_cat?(response.body[:data])
            remove_service_type(response.body[:data])
          end

          # set requestedPeriods to nil if the appointment is a booked cerner appointment per GH#62912
          if booked?(response.body[:data]) && cerner?(response.body[:data])
            response.body[:data][:requested_periods] = nil
          end

          if avs_applicable?(response.body[:data]) && Flipper.enabled?(AVS_FLIPPER, user)
            fetch_avs_and_update_appt_body(response.body[:data])
          end

          OpenStruct.new(response.body[:data])
        end
      end

      def post_appointment(request_object_body)
        params = VAOS::V2::AppointmentForm.new(user, request_object_body).params.with_indifferent_access
        params.compact_blank!
        with_monitoring do
          response = perform(:post, appointments_base_path, params, headers)
          convert_appointment_time(response.body)
          OpenStruct.new(response.body)
        rescue Common::Exceptions::BackendServiceException => e
          log_direct_schedule_submission_errors(e) if params[:status] == 'booked'
          raise e
        end
      end

      def update_appointment(appt_id, status)
        with_monitoring do
          response = if Flipper.enabled?(ORACLE_HEALTH_CANCELLATIONS)
                       update_appointment_vpg(appt_id, status)
                     else
                       update_appointment_vaos(appt_id, status)
                     end

          convert_appointment_time(response.body)
          OpenStruct.new(response.body)
        end
      end

      # Retrieves the most recent clinic appointment within the last year.
      #
      # Returns:
      # - The most recent appointment of kind == 'clinic' or
      # - nil if no appointment is found.
      #
      def get_most_recent_visited_clinic_appointment
        current_check = Date.current.end_of_day.yesterday
        three_month_interval = 3.months
        look_back_limit = 1.year.ago
        statuses = 'booked,fulfilled,arrived'

        # starting yesterday loop in three month intervals until we find an appointment
        # or we run into the look back limit
        while current_check > look_back_limit
          end_time = current_check
          start_time = current_check - three_month_interval

          appointments = fetch_clinic_appointments(start_time, end_time, statuses)

          return most_recent_appointment(appointments) unless appointments.empty?

          current_check -= three_month_interval
        end

        nil
      end

      private

      def fetch_clinic_appointments(start_time, end_time, statuses)
        get_appointments(start_time, end_time, statuses)[:data].select { |appt| appt.kind == 'clinic' }
      end

      def most_recent_appointment(appointments)
        appointments.max_by { |appointment| DateTime.parse(appointment.start) }
      end

      def mobile_facility_service
        @mobile_facility_service ||=
          VAOS::V2::MobileFacilityService.new(user)
      end

      def avs_service
        @avs_service ||=
          Avs::V0::AvsService.new
      end

      # Extracts the station number and appointment IEN from an Appointment.
      #
      # Given an appointment, this method will check the identifiers, find the identifier associated
      # with 'VistADefinedTerms/409_84' or 'VistADefinedTerms/409_85' and return the identifier value
      # as a two-item array (split on the ':' character). If there is no such identifier, it will return nil.
      #
      # @param [Hash] appointment The appointment object to find the identifier in.
      # This Hash must include an :identifier key.
      #
      # @return [Array, nil] An array containing two strings representing the station number
      # and IEN if found, or nil if not.
      def extract_station_and_ien(appointment)
        return nil if appointment[:identifier].nil?

        regex = %r{VistADefinedTerms/409_(84|85)}
        identifier = appointment[:identifier].find { |id| id[:system]&.match? regex }

        return if identifier.nil?

        identifier[:value]&.split(':', 2)
      end

      # Normalizes an Integration Control Number (ICN) by removing the 'V' character and the trailing six digits.
      # The ICN format consists of 17 alpha-numeric characters (10 digits + "V" + 6 digits) with
      # V being a deliminator, and the 6 trailing digits a checksum.
      #
      # @param [String] icn The input ICN to be normalized.
      #
      # @return [String, nil] The normalized ICN as a string, after removing the trailing pattern 'V\[\d\]{6}',
      # or nil if the input ICN was nil.
      #
      def normalize_icn(icn)
        icn&.gsub(/V[\d]{6}$/, '')
      end

      # Checks equality between two ICNs (Integration Control Numbers)
      # after normalizing them.
      #
      # @param [String] icn_a The first ICN to be compared.
      # @param [String] icn_b The second ICN to be compared.
      #
      # @return [Boolean] Returns true if the normalized versions of icn_a and icn_b are equal,
      # false if they are not equal or if either icn is nil.
      def icns_match?(icn_a, icn_b)
        return false if icn_a.nil? || icn_b.nil?

        normalize_icn(icn_a) == normalize_icn(icn_b)
      end

      # Retrieves a link to the After Visit Summary (AVS) for a given appointment.
      #
      # @param appt [Hash] The appointment for which to retrieve an AVS link.
      # @return [String, nil] The AVS link associated with the appointment,
      # or nil if no link could be found or if there was a mismatch in Integration Control Numbers (ICNs).
      def get_avs_link(appt)
        station_no, appt_ien = extract_station_and_ien(appt)

        return nil if station_no.nil? || appt_ien.nil?

        avs_resp = avs_service.get_avs_by_appointment(station_no, appt_ien)

        return nil if avs_resp.body.empty?

        data = avs_resp.body.first.with_indifferent_access

        if data[:icn].nil? || !icns_match?(data[:icn], user[:icn])
          Rails.logger.warn('VAOS: AVS response ICN does not match user ICN')
          return nil
        end

        avs_path(data[:sid])
      end

      # Fetches the After Visit Summary (AVS) link for an appointment and updates the `:avs_path` of the `appt`..
      #
      # In case of an error the method logs the error details and sets the `:avs_path` attribute of `appt` to `nil`.
      #
      # @param [Hash] appt The object representing the appointment. Must be an object that allows hash-like access
      #
      # @return [nil] This method does not explicitly return a value. It modifies the `appt`.
      def fetch_avs_and_update_appt_body(appt)
        # Testing AVS empty state using the below id - remove after testing is complete
        if appt[:id] == AVS_APPT_TEST_ID
          appt[:avs_path] = nil
        else
          avs_link = get_avs_link(appt)
          appt[:avs_path] = avs_link
        end
      rescue => e
        err_stack = e.backtrace.reject { |line| line.include?('gems') }.compact.join("\n   ")
        Rails.logger.error("VAOS: Error retrieving AVS link: #{e.class}, #{e.message} \n   #{err_stack}")
        appt[:avs_path] = AVS_ERROR_MESSAGE
      end

      # Checks if appointment is eligible for receiving an AVS link, i.e.
      # the appointment is booked and in the past
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is eligible, false otherwise
      #
      def avs_applicable?(appt)
        return false if appt.nil? || appt[:status].nil? || appt[:start].nil?

        appt[:status] == 'booked' && appt[:start].to_datetime.past?
      end

      # Checks if the appointment is booked.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is booked, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def booked?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:status] == 'booked'
      end

      # Get codes from a list of codeable concepts.
      #
      # @param input [Array<Hash>] An array of codeable concepts.
      # @return [Array<String>] An array of codes.
      #
      def codes(input)
        return [] if input.nil?

        input.flat_map { |codeable_concept| codeable_concept[:coding]&.pluck(:code) }.compact
      end

      def lovell_appointment?(appt)
        return false if appt.nil? || appt[:location_id].nil?

        appt[:location_id].start_with?('556')
      end

      # Checks if the appointment is associated with cerner. It looks through each identifier and checks if the system
      # contains cerner. If it does, it returns true. Otherwise, it returns false.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is associated with cerner, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      def cerner?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        identifiers = appt[:identifier]

        return false if identifiers.nil?

        identifiers.each do |identifier|
          system = identifier[:system]
          return true if system.include?('cerner')
        end

        false
      end

      # Determines if the appointment is for compensation and pension.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for compensation and pension, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def cnp?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_category]).include? 'COMPENSATION & PENSION'
      end

      # Determines if the appointment is for covid.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for covid, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def covid?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_types]).include?('covid') || appt[:service_type] == 'covid'
      end

      # Determines if the appointment is a medical appointment.
      #
      # @param appt [Hash] The hash object containing appointment details.
      # @return [Boolean] true if the appointment is a medical appointment, false otherwise.
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def medical?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_category]).include?('REGULAR')
      end

      # Determines if the appointment does not have a service category.
      #
      # @param appt [Hash] The hash object containing appointment details.
      # @return [Boolean] true if the appointment does not have a service category, false otherwise.
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def no_service_cat?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        codes(appt[:service_category]).empty?
      end

      # Modifies the appointment removing the service types and service type elements.
      #
      # @param appt [Hash] The hash object containing appointment details.
      #
      # @raises [ArgumentError] if the given appointment is nil.
      #
      def remove_service_type(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt.delete(:service_type)
        appt.delete(:service_types)
        nil
      end

      # Entry point for processing appointment responses for converting their times from UTC to local.
      # Uses the location_id from the appt body to fetch the facility's timezone that is then passed along
      # with the appointment time to the convert_utc_to_local_time method which does the actual conversion.
      def convert_appointment_time(appt)
        if !appt[:start].nil?
          facility_timezone = get_facility_timezone_memoized(appt[:location_id])
          appt[:local_start_time] = convert_utc_to_local_time(appt[:start], facility_timezone)
        elsif !appt.dig(:requested_periods, 0, :start).nil?
          appt[:requested_periods].each do |period|
            facility_timezone = get_facility_timezone_memoized(appt[:location_id])
            period[:local_start_time] = convert_utc_to_local_time(period[:start], facility_timezone)
          end
        end
        appt
      end

      # Returns a local [DateTime] object converted from UTC using the facility's timezone offset.
      # We'd like to perform this change only on the appointment responses to offer a consistently
      # formatted local time to our consumers while not changing how we pass DateTimes to upstream services.
      #
      # @param [DateTime] date - the date to be modified, required
      # @param [String] tz - the timezone id, won't convert if nil
      # @return [DateTime] date in local time, will return in UTC if tz is nil
      #
      def convert_utc_to_local_time(date, tz)
        raise Common::Exceptions::ParameterMissing, 'date' if date.nil?

        if tz.nil?
          'Unable to convert UTC to local time'
        else
          date.to_time.utc.in_time_zone(tz).to_datetime
        end
      end

      # Returns the facility timezone id (eg. 'America/New_York') associated with facility id (location_id)
      def get_facility_timezone_memoized(facility_location_id)
        facility_info = get_facility(facility_location_id) unless facility_location_id.nil?
        if facility_info == FACILITY_ERROR_MSG || facility_info.nil?
          nil # returns nil if unable to fetch facility info, which will be handled by the timezone conversion
        else
          facility_info[:timezone]&.[](:time_zone_id)
        end
      end
      memoize :get_facility_timezone_memoized

      def get_facility(location_id)
        mobile_facility_service.get_facility_with_cache(location_id)
      rescue Common::Exceptions::BackendServiceException
        Rails.logger.error(
          "Error fetching facility details for location_id #{location_id}",
          location_id:
        )
        FACILITY_ERROR_MSG
      end

      def log_direct_schedule_submission_errors(e)
        error_entry = { DIRECT_SCHEDULE_ERROR_KEY => ds_error_details(e) }
        Rails.logger.warn('Direct schedule submission error', error_entry.to_json)
      end

      # Modifies the appointment, setting the cancellable flag to false
      #
      # @param appointment [Hash] the appointment to modify
      def set_cancellable_false(appointment)
        appointment[:cancellable] = false
      end

      def ds_error_details(e)
        {
          status: e.status_code,
          message: e.message
        }
      end

      def deserialized_appointments(appointment_list)
        return [] unless appointment_list

        appointment_list.map { |appointment| OpenStruct.new(appointment) }
      end

      def pagination(pagination_params)
        {
          pagination: {
            current_page: pagination_params[:page] || 0,
            per_page: pagination_params[:per_page] || 0,
            total_pages: 0, # underlying api doesn't provide this; how do you build a pagination UI without it?
            total_entries: 0 # underlying api doesn't provide this.
          }
        }
      end

      def partial_errors(response)
        if response.status == 200 && response.body[:failures]&.any?
          log_message_to_sentry(
            'VAOS::V2::AppointmentService#get_appointments has response errors.',
            :info,
            failures: response.body[:failures].to_json
          )
        end

        {
          failures: response.body[:failures] || [] # VAMF drops null valued keys; ensure we always return empty array
        }
      end

      def appointments_base_path
        "/vaos/v1/patients/#{user.icn}/appointments"
      end

      def avs_path(sid)
        "/my-health/medical-records/summaries-and-notes/visit-summary/#{sid}"
      end

      def get_appointment_base_path(appointment_id)
        "/vaos/v1/patients/#{user.icn}/appointments/#{appointment_id}"
      end

      def date_params(start_date, end_date)
        { start: date_format(start_date), end: date_format(end_date) }
      end

      def status_params(statuses)
        { statuses: }
      end

      def page_params(pagination_params)
        if pagination_params[:per_page]&.positive?
          { pageSize: pagination_params[:per_page], page: pagination_params[:page] }
        else
          { pageSize: pagination_params[:per_page] || 0 }
        end
      end

      def date_format(date)
        date.strftime('%Y-%m-%dT%TZ')
      end

      def update_appointment_vpg(appt_id, status)
        url_path = "/vpg/v1/patients/#{user.icn}/appointments/#{appt_id}"
        body = JSON.generate([VAOS::V2::UpdateAppointmentForm.new(status:).json_patch_op])
        perform(:patch, url_path, body, headers)
      end

      def update_appointment_vaos(appt_id, status)
        url_path = "/vaos/v1/patients/#{user.icn}/appointments/#{appt_id}"
        params = VAOS::V2::UpdateAppointmentForm.new(status:).params
        perform(:put, url_path, params, headers)
      end
    end
  end
end
