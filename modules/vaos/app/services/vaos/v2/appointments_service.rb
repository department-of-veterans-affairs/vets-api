# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class AppointmentsService < VAOS::SessionService
      DIRECT_SCHEDULE_ERROR_KEY = 'DirectScheduleError'
      VAOS_SERVICE_DATA_KEY = 'VAOSServiceTypesAndCategory'
      VAOS_TELEHEALTH_DATA_KEY = 'VAOSTelehealthData'
      FACILITY_ERROR_MSG = 'Error fetching facility details'

      def get_appointments(start_date, end_date, statuses = nil, pagination_params = {})
        params = date_params(start_date, end_date)
                 .merge(page_params(pagination_params))
                 .merge(status_params(statuses))
                 .compact

        with_monitoring do
          response = perform(:get, appointments_base_url, params, headers)
          response.body[:data].each do |appt|
            # for CnP appointments set cancellable to false per GH#57824
            set_cancellable_false(appt) if cnp?(appt)
            # for covid appointments set cancellable to false per GH#58690
            set_cancellable_false(appt) if covid?(appt)

            find_service_type_and_category(appt)
            log_telehealth_data(appt[:telehealth]&.[](:atlas)) unless appt[:telehealth]&.[](:atlas).nil?
            convert_appointment_time(appt)
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
          response = perform(:get, get_appointment_base_url(appointment_id), params, headers)
          convert_appointment_time(response.body[:data])
          # for CnP appointments set cancellable to false per GH#57824
          set_cancellable_false(response.body[:data]) if cnp?(response.body[:data])
          # for covid appointments set cancellable to false per GH#58690
          set_cancellable_false(response.body[:data]) if covid?(response.body[:data])
          OpenStruct.new(response.body[:data])
        end
      end

      def post_appointment(request_object_body)
        params = VAOS::V2::AppointmentForm.new(user, request_object_body).params.with_indifferent_access
        params.compact_blank!
        with_monitoring do
          response = perform(:post, appointments_base_url, params, headers)
          find_service_type_and_category(response.body)
          log_telehealth_data(response.body[:telehealth]&.[](:atlas)) unless response.body[:telehealth]&.[](:atlas).nil?
          OpenStruct.new(response.body)
        rescue Common::Exceptions::BackendServiceException => e
          log_direct_schedule_submission_errors(e) if params[:status] == 'booked'
          raise e
        end
      end

      def update_appointment(appt_id, status)
        url_path = "/vaos/v1/patients/#{user.icn}/appointments/#{appt_id}"
        params = VAOS::V2::UpdateAppointmentForm.new(status:).params
        with_monitoring do
          response = perform(:put, url_path, params, headers)
          OpenStruct.new(response.body)
        end
      end

      private

      def mobile_facility_service
        @mobile_facility_service ||=
          VAOS::V2::MobileFacilityService.new(user)
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

      # Returns true if the appointment is for compensation and pension, false otherwise.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for compensation and pension, false otherwise
      #
      def cnp?(appt)
        codes(appt[:service_category]).include? 'COMPENSATION & PENSION'
      end

      # Returns true if the appointment is for covid, false otherwise.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for covid, false otherwise
      #
      def covid?(appt)
        codes(appt[:service_types]).include?('covid') || appt[:service_type] == 'covid'
      end

      # Entry point for processing appointment responses for converting their times from UTC to local.
      # Uses the location_id from the appt body to fetch the facility's timezone that is then passed along
      # with the appointment time to the convert_utc_to_local_time method which does the actual conversion.
      def convert_appointment_time(appt)
        if !appt[:start].nil?
          facility_timezone = get_facility_timezone(appt[:location_id])
          appt[:start] = convert_utc_to_local_time(appt[:start], facility_timezone)
        elsif !appt.dig(:requested_periods, 0, :start).nil?
          appt[:requested_periods].each do |period|
            facility_timezone = get_facility_timezone(appt[:location_id])
            period[:start] = convert_utc_to_local_time(period[:start], facility_timezone)
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

        date.to_time.utc.in_time_zone(tz).to_datetime
      end

      # Returns the facility timezone id (eg. 'America/New_York') associated with facility id (location_id)
      def get_facility_timezone(facility_location_id)
        facility_info = get_facility(facility_location_id) unless facility_location_id.nil?
        if facility_info == FACILITY_ERROR_MSG || facility_info.nil?
          nil # returns nil if unable to fetch facility info, which will be handled by the timezone conversion
        else
          facility_info[:timezone]&.[](:zone_id)
        end
      end

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

      def log_telehealth_data(atlas_data)
        atlas_entry = { VAOS_TELEHEALTH_DATA_KEY => atlas_details(atlas_data) }
        Rails.logger.info('VAOS telehealth atlas details', atlas_entry.to_json)
      end

      def atlas_details(atlas_data)
        {
          siteCode: atlas_data&.[](:site_code),
          address: atlas_data&.[](:address)
        }
      end

      def find_service_type_and_category(appt)
        appointment_kind = appt&.[](:kind)
        service_category_found = if appt.dig(:service_category, 0, :coding, 0,
                                             :code).nil?
                                   'ServiceCategoryNotFound'
                                 else
                                   appt.dig(:service_category, 0, :coding, 0,
                                            :code)
                                 end
        service_types_found = if appt.dig(:service_types, 0, :coding, 0,
                                          :code).nil?
                                'ServiceTypesNotFound'
                              else
                                appt.dig(:service_types, 0, :coding, 0,
                                         :code)
                              end
        service_type_found = appt[:service_type].nil? ? 'ServiceTypeNotFound' : appt[:service_type]
        log_service_type_and_category(type_and_category_data(appointment_kind, service_type_found, service_types_found,
                                                             service_category_found))
      end

      def type_and_category_data(kind, type, types, category)
        {
          vaos_appointment_kind: kind,
          vaos_service_type: type,
          vaos_service_types: types,
          vaos_service_category: category
        }
      end

      def log_service_type_and_category(service_data)
        service_log_entry = { VAOS_SERVICE_DATA_KEY => service_data }
        Rails.logger.info('VAOS appointment service category and type', service_log_entry.to_json)
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
          failures: (response.body[:failures] || []) # VAMF drops null valued keys; ensure we always return empty array
        }
      end

      def appointments_base_url
        "/vaos/v1/patients/#{user.icn}/appointments"
      end

      def get_appointment_base_url(appointment_id)
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
    end
  end
end
