# frozen_string_literal: true

require 'common/exceptions'
require 'memoist'

module VAOS
  module V2
    class AppointmentsController < VAOS::BaseController
      extend Memoist

      STATSD_KEY = 'api.vaos.va_mobile.response.partial'
      PAP_COMPLIANCE_TELE = 'PAP COMPLIANCE/TELE'
      FACILITY_ERROR_MSG = 'Error fetching facility details'
      APPT_INDEX = "GET '/vaos/v1/patients/<icn>/appointments'"
      APPT_SHOW = "GET '/vaos/v1/patients/<icn>/appointments/<id>'"
      APPT_CREATE = "POST '/vaos/v1/patients/<icn>/appointments'"
      REASON = 'reason'
      REASON_CODE = 'reason_code'
      COMMENT = 'comment'

      def index
        appointments

        appointments[:data].each do |appt|
          scrape_appt_comments_and_log_details(appt, APPT_INDEX, PAP_COMPLIANCE_TELE)
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointments[:data], 'appointments')

        if !appointments[:meta][:failures]&.empty?
          StatsDMetric.new(key: STATSD_KEY).save
          StatsD.increment(STATSD_KEY, tags: ["failures:#{appointments[:meta][:failures]}"])
          render json: { data: serialized, meta: appointments[:meta] }, status: :multi_status
        else
          render json: { data: serialized, meta: appointments[:meta] }, status: :ok
        end
      end

      def show
        appointment

        unless appointment[:clinic].nil? || appointment[:location_id].nil?
          # clinic = get_clinic_memoized(appointment[:location_id], appointment[:clinic])
          appointment[:service_name] = clinic&.[](:service_name)
          appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          appointment[:friendly_name] = clinic&.[](:service_name) if clinic&.[](:service_name)
        end

        unless appointment[:location_id].nil?
          appointment[:location] =
            appointments_service.get_facility_memoized(appointment[:location_id])
        end

        scrape_appt_comments_and_log_details(appointment, APPT_SHOW, PAP_COMPLIANCE_TELE)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointment, 'appointments')
        render json: { data: serialized }
      end

      def create
        new_appointment

        unless new_appointment[:clinic].nil? || new_appointment[:location_id].nil?
          # clinic = get_clinic_memoized(new_appointment[:location_id], new_appointment[:clinic])
          new_appointment[:service_name] = clinic&.[](:service_name)
          new_appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          new_appointment[:friendly_name] = clinic&.[](:service_name) if clinic&.[](:service_name)
        end

        unless new_appointment[:location_id].nil?
          new_appointment[:location] = appointments_service.get_facility_memoized(new_appointment[:location_id])
        end

        scrape_appt_comments_and_log_details(new_appointment, APPT_CREATE, PAP_COMPLIANCE_TELE)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointments')
        render json: { data: serialized }, status: :created
      end

      def update
        updated_appointment
        unless updated_appointment[:clinic].nil? || updated_appointment[:location_id].nil?
          # clinic = get_clinic_memoized(updated_appointment[:location_id], updated_appointment[:clinic])
          updated_appointment[:service_name] = clinic&.[](:service_name)
          updated_appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          updated_appointment[:friendly_name] = clinic&.[](:service_name) if clinic&.[](:service_name)
        end

        unless updated_appointment[:location_id].nil?
          updated_appointment[:location] = appointments_service.get_facility_memoized(updated_appointment[:location_id])
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(updated_appointment, 'appointments')
        render json: { data: serialized }
      end

      private

      def appointments_service
        @appointments_service ||=
          VAOS::V2::AppointmentsService.new(current_user)
      end

      def mobile_facility_service
        @mobile_facility_service ||=
          VAOS::V2::MobileFacilityService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, statuses, pagination_params, include_params)
      end

      def appointment
        @appointment ||=
          appointments_service.get_appointment(appointment_id)
      end

      def new_appointment
        @new_appointment ||= get_new_appointment
      end

      def updated_appointment
        @updated_appointment ||=
          appointments_service.update_appointment(update_appt_id, status_update)
      end

      # Makes a call to the VAOS service to create a new appointment.
      def get_new_appointment
        if create_params[:kind] == 'clinic' && create_params[:status] == 'booked' # a direct scheduled appointment
          modify_desired_date(create_params, appointments_service.get_facility_timezone(create_params[:location_id]))
        end

        appointments_service.post_appointment(create_params)
      end

      # Modifies params so that the facility timezone offset is included in the desired date.
      # The desired date is sent in this format: 2019-12-31T00:00:00-00:00
      # This modifies the params in place. If params does not contain a desired date, it is not modified.
      #
      # @param [ActionController::Parameters] create_params - the params to be modified
      # @param [String] timezone - the facility timezone id
      def modify_desired_date(create_params, timezone)
        desired_date = create_params[:extension]&.[](:desired_date)

        return create_params if desired_date.nil?

        create_params[:extension][:desired_date] = add_timezone_offset(desired_date, timezone)
      end

      # Returns a [DateTime] object with the timezone offset added. Given a desired date of 2019-12-31T00:00:00-00:00
      # and a timezone of America/New_York, the returned date will be 2019-12-31T00:00:00-05:00.
      #
      # @param [DateTime] date - the date to be modified,  required
      # @param [String] tz - the timezone id, if nil, the offset is not added
      # @return [DateTime] date with timezone offset
      #
      def add_timezone_offset(date, tz)
        raise Common::Exceptions::ParameterMissing, 'date' if date.nil?

        utc_date = date.to_time.utc
        timezone_offset = utc_date.in_time_zone(tz).formatted_offset
        utc_date.change(offset: timezone_offset).to_datetime
      end

      # Checks if the appointment is associated with cerner. It looks through each identifier and checks if the system
      # contains cerner. If it does, it returns true. Otherwise, it returns false.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is associated with cerner, false otherwise
      def cerner?(appt)
        return false if appt.nil?

        identifiers = appt[:identifier]

        return false if identifiers.nil?

        identifiers.each do |identifier|
          system = identifier[:system]
          return true if system.include?('cerner')
        end

        false
      end

      def appt_cerner_location_data(appt_id, facility_location_id, facility_name)
        {
          appt_id:,
          facility_location_id:,
          facility_name:
        }
      end

      # This method extracts all values from a given object, which can be either an `OpenStruct`, `Hash`, or `Array`.
      # It recursively traverses the object and collects all values into an array.
      # In case of an `Array`, it looks inside each element of the array for values.
      # If the object is neither an OpenStruct, Hash, nor an Array, it returns the unmodified object in an array.
      #
      # @param object [OpenStruct, Hash, Array] The object from which to extract values.
      # This could either be an OpenStruct, Hash or Array.
      #
      # @return [Array] An array of all values found in the object.
      # If the object is not an OpenStruct, Hash, nor an Array, then the unmodified object is returned.
      #
      # @example
      #   extract_all_values({a: 1, b: 2, c: {d: 3, e: 4}})  # => [1, 2, 3, 4]
      #   extract_all_values(OpenStruct.new(a: 1, b: 2, c: OpenStruct.new(d: 3, e: 4))) # => [1, 2, 3, 4]
      #   extract_all_values([{a: 1}, {b: 2}]) # => [1, 2]
      #   extract_all_values({a: 1, b: [{c: 2}, {d: "hello"}]}) # => [1, 2, "hello"]
      #   extract_all_values("not a hash, openstruct, or array")  # => ["not a hash, openstruct, or array"]
      #
      def extract_all_values(object)
        return [object] unless object.is_a?(OpenStruct) || object.is_a?(Hash) || object.is_a?(Array)

        values = []
        object = object.to_h if object.is_a?(OpenStruct)

        if object.is_a?(Array)
          object.each do |o|
            values += extract_all_values(o)
          end
        else
          object.each_pair do |_, value|
            case value
            when OpenStruct, Hash, Array then values += extract_all_values(value)
            else values << value
            end
          end
        end

        values
      end

      # This method checks if any string element in the given array contains the specified substring.
      #
      # @param arr [Array] The array to be searched.
      # @param substring [String] The substring to look for.
      #
      # @return [Boolean] Returns true if any string element in the array contains the substring, false otherwise.
      # If the input parameters are not of the correct type the method will return false.
      #
      # @example
      #   contains_substring(['Hello', 'World'], 'ell')  # => true
      #   contains_substring(['Hello', 'World'], 'xyz')  # => false
      #   contains_substring('Hello', 'ell')  # => false
      #   contains_substring(['Hello', 'World'], 123)  # => false
      #
      def contains_substring(arr, substring)
        return false unless arr.is_a?(Array) && substring.is_a?(String)

        arr.any? { |element| element.is_a?(String) && element.include?(substring) }
      end

      def scrape_appt_comments_and_log_details(appt, appt_method, comment_key)
        if appt&.[](:reason)&.include? comment_key
          log_appt_comment_data(appt, appt_method, appt&.[](:reason), comment_key, REASON)
        elsif appt&.[](:comment)&.include? comment_key
          log_appt_comment_data(appt, appt_method, appt&.[](:comment), comment_key, COMMENT)
        elsif appt&.[](:reason_code)&.[](:text)&.include? comment_key
          log_appt_comment_data(appt, appt_method, appt&.[](:reason_code)&.[](:text), comment_key, REASON_CODE)
        end
      end

      def log_appt_comment_data(appt, appt_method, comment_content, comment_key, field_name)
        appt_comment_data_entry = { "#{comment_key} appointment details" => appt_comment_log_details(appt, appt_method,
                                                                                                     comment_content,
                                                                                                     field_name) }
        Rails.logger.info("Details for #{comment_key} appointment", appt_comment_data_entry.to_json)
      end

      def appt_comment_log_details(appt, appt_method, comment_content, field_name)
        {
          endpoint_method: appt_method,
          appointment_id: appt[:id],
          appointment_status: appt[:status],
          location_id: appt[:location_id],
          clinic: appt[:clinic],
          field_name:,
          comment: comment_content
        }
      end

      def update_appt_id
        params.require(:id)
      end

      def status_update
        params.require(:status)
      end

      def appointment_params
        params.require(:start)
        params.require(:end)
        params.permit(:start, :end, :_include)
      end

      # rubocop:disable Metrics/MethodLength
      def create_params
        @create_params ||= begin
          # Gets around a bug that turns param values of [] into [""]. This changes them back to [].
          # Without this the VAOS Service POST appointments call will fail as VAOS Service tries to parse [""].
          params.transform_values! { |v| v.is_a?(Array) && v.count == 1 && (v[0] == '') ? [] : v }

          params.permit(
            :kind,
            :status,
            :location_id,
            :cancellable,
            :clinic,
            :comment,
            :reason,
            :service_type,
            :preferred_language,
            :minutes_duration,
            :patient_instruction,
            :priority,
            reason_code: [
              :text, { coding: %i[system code display] }
            ],
            slot: %i[id start end],
            contact: [telecom: %i[type value]],
            practitioner_ids: %i[system value],
            requested_periods: %i[start end],
            practitioners: [
              :first_name,
              :last_name,
              :practice_name,
              {
                name: %i[family given]
              },
              {
                identifier: %i[system value]
              },
              {
                address: [
                  :type,
                  { line: [] },
                  :city,
                  :state,
                  :postal_code,
                  :country,
                  :text
                ]
              }
            ],
            preferred_location: %i[city state],
            preferred_times_for_phone_call: [],
            telehealth: [
              :url,
              :group,
              :vvs_kind,
              {
                atlas: [
                  :site_code,
                  :confirmation_code,
                  {
                    address: %i[
                      street_address city state
                      zip country latitude longitude
                      additional_details
                    ]
                  }
                ]
              }
            ],
            extension: %i[desired_date]
          )
        end
      end
      # rubocop:enable Metrics/MethodLength

      def start_date
        DateTime.parse(appointment_params[:start]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start', params[:start])
      end

      def end_date
        DateTime.parse(appointment_params[:end]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end', params[:end])
      end

      def include_params
        included = appointment_params[:_include]&.split(',')
        {
          clinics: included&.include?('clinics'),
          facilities: included&.include?('facilities')
        }
      end

      def statuses
        s = params[:statuses]
        s.is_a?(Array) ? s.to_csv(row_sep: nil) : s
      end

      def appointment_id
        params[:appointment_id]
      end
    end
  end
end
