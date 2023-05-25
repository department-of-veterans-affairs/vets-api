# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::BaseController
      STATSD_KEY = 'api.vaos.va_mobile.response.partial'

      # cache utilized by the controller to store key/value pairs of provider name and npi
      # in order to prevent duplicate service call lookups during index/show/create
      @@provider_cache = {} # rubocop:disable Style/ClassVars

      def index
        appointments

        appointments[:data].each do |appt|
          find_and_merge_provider_name(appt) if appt[:kind] == 'cc' && appt[:status] == 'proposed'
        end

        # clear provider cache after processing appointments
        clear_provider_cache

        _include&.include?('clinics') && merge_clinics(appointments[:data])
        _include&.include?('facilities') && merge_facilities(appointments[:data])

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

        find_and_merge_provider_name(appointment) if appointment[:kind] == 'cc' && appointment[:status] == 'proposed'
        clear_provider_cache

        unless appointment[:clinic].nil? || appointment[:location_id].nil?
          clinic = get_clinic(appointment[:location_id], appointment[:clinic])
          appointment[:service_name] = clinic&.[](:service_name)
          appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          appointment[:friendly_name] = clinic&.[](:friendly_name) if clinic&.[](:friendly_name)
        end

        appointment[:location] = get_facility(appointment[:location_id]) unless appointment[:location_id].nil?

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointment, 'appointments')
        render json: { data: serialized }
      end

      def create
        new_appointment

        find_and_merge_provider_name(new_appointment) if new_appointment[:kind] == 'cc'
        clear_provider_cache

        unless new_appointment[:clinic].nil? || new_appointment[:location_id].nil?
          clinic = get_clinic(new_appointment[:location_id], new_appointment[:clinic])
          new_appointment[:service_name] = clinic&.[](:service_name)
          new_appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          new_appointment[:friendly_name] = clinic&.[](:friendly_name) if clinic&.[](:friendly_name)
        end

        unless new_appointment[:location_id].nil?
          new_appointment[:location] = get_facility(new_appointment[:location_id])
        end
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointments')
        render json: { data: serialized }, status: :created
      end

      def update
        updated_appointment
        unless updated_appointment[:clinic].nil? || updated_appointment[:location_id].nil?
          clinic = get_clinic(updated_appointment[:location_id], updated_appointment[:clinic])
          updated_appointment[:service_name] = clinic&.[](:service_name)
          updated_appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          updated_appointment[:friendly_name] = clinic&.[](:friendly_name) if clinic&.[](:friendly_name)
        end

        unless updated_appointment[:location_id].nil?
          updated_appointment[:location] = get_facility(updated_appointment[:location_id])
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

      def systems_service
        @systems_service ||=
          VAOS::V2::SystemsService.new(current_user)
      end

      def mobile_facility_service
        @mobile_facility_service ||=
          VAOS::V2::MobileFacilityService.new(current_user)
      end

      def mobile_ppms_service
        @mobile_ppms_service ||=
          VAOS::V2::MobilePPMSService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, statuses, pagination_params)
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

      # uses find_npi helper method to extract npi from appointment response,
      # then uses the npi to look up the provider name via mobile_ppms_service
      #
      # will cache at the class level the key value pair of npi and provider name to avoid
      # duplicate get_provider_with_cache calls

      NPI_NOT_FOUND_MSG = "We're sorry, we can't display your provider's information right now."

      def find_and_merge_provider_name(appt)
        found_npi = find_npi(appt)
        if found_npi
          if !read_provider_cache(found_npi)
            begin
              provider_response = mobile_ppms_service.get_provider_with_cache(found_npi)
              appt[:preferred_provider_name] = provider_response[:name]
            rescue Common::Exceptions::BackendServiceException => e
              appt[:preferred_provider_name] = NPI_NOT_FOUND_MSG
              Rails.logger.warn(
                "Error fetching provider name for npi #{found_npi}",
                npi: found_npi,
                vamf_msg: e.original_body
              )
            end
            write_provider_cache(found_npi, appt[:preferred_provider_name])
          else
            appt[:preferred_provider_name] = read_provider_cache(found_npi)
          end
        end
      end

      def find_npi(appt)
        appt[:practitioners]&.each do |a|
          a[:identifier]&.each do |i|
            return i[:value] if i[:system].include? 'us-npi'
          end
        end
        nil
      end

      def clear_provider_cache
        @@provider_cache = {} # rubocop:disable Style/ClassVars
      end

      def read_provider_cache(key)
        @@provider_cache[key]
      end

      def write_provider_cache(key, value)
        @@provider_cache[key] = value
      end

      # Makes a call to the VAOS service to create a new appointment.
      def get_new_appointment
        if create_params[:kind] == 'clinic' && create_params[:status] == 'booked' # a direct scheduled appointment
          modify_desired_date(create_params, get_facility_timezone(create_params[:location_id]))
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

      FACILITY_ERROR_MSG = 'Error fetching facility details'

      # Returns the facility timezone id (eg. 'America/New_York') associated with facility id (location_id)
      def get_facility_timezone(facility_location_id)
        facility_info = get_facility(facility_location_id)
        if facility_info == FACILITY_ERROR_MSG
          nil # returns nil if unable to fetch facility info, which will be handled by the timezone conversion
        else
          facility_info[:timezone]&.[](:time_zone_id)
        end
      end

      def merge_clinics(appointments)
        cached_clinics = {}
        appointments.each do |appt|
          unless appt[:clinic].nil? || appt[:location_id].nil?
            unless cached_clinics[appt[:clinic]]
              clinic = get_clinic(appt[:location_id], appt[:clinic])
              cached_clinics[appt[:clinic]] = clinic
            end
            if cached_clinics[appt[:clinic]]&.[](:service_name)
              appt[:service_name] = cached_clinics[appt[:clinic]][:service_name]
            end
            if cached_clinics[appt[:clinic]]&.[](:physical_location)
              appt[:physical_location] = cached_clinics[appt[:clinic]][:physical_location]
            end
            if cached_clinics[appt[:clinic]]&.[](:friendly_name)
              appt[:friendly_name] = cached_clinics[appt[:clinic]][:friendly_name]
            end
          end
        end
      end

      def merge_facilities(appointments)
        cached_facilities = {}
        appointments.each do |appt|
          unless appt[:location_id].nil?
            unless cached_facilities[appt[:location_id]]
              facility = get_facility(appt[:location_id])
              cached_facilities[appt[:location_id]] = facility
            end

            appt[:location] = cached_facilities[appt[:location_id]] if cached_facilities[appt[:location_id]]
          end
        end
      end

      def get_clinic(location_id, clinic_id)
        mobile_facility_service.get_clinic_with_cache(station_id: location_id, clinic_id:)
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error(
          "Error fetching clinic #{clinic_id} for location #{location_id}",
          clinic_id:,
          location_id:,
          vamf_msg: e.original_body
        )
        nil # on error log and return nil, calling code will handle nil
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

      def _include
        appointment_params[:_include]&.split(',')
      end

      def statuses
        s = params[:statuses]
        s.is_a?(Array) ? s.to_csv(row_sep: nil) : s
      end

      def appointment_id
        params[:appointment_id]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('appointment_id', params[:appointment_id])
      end
    end
  end
end
