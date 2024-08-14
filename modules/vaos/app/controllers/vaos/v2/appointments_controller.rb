# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::BaseController
      STATSD_KEY = 'api.vaos.va_mobile.response.partial'
      PAP_COMPLIANCE_TELE = 'PAP COMPLIANCE/TELE'
      FACILITY_ERROR_MSG = 'Error fetching facility details'
      APPT_INDEX_VAOS = "GET '/vaos/v1/patients/<icn>/appointments'"
      APPT_INDEX_VPG = "GET '/vpg/v1/patients/<icn>/appointments'"
      APPT_SHOW_VAOS = "GET '/vaos/v1/patients/<icn>/appointments/<id>'"
      APPT_SHOW_VPG = "GET '/vpg/v1/patients/<icn>/appointments/<id>'"
      APPT_CREATE_VAOS = "POST '/vaos/v1/patients/<icn>/appointments'"
      APPT_CREATE_VPG = "POST '/vpg/v1/patients/<icn>/appointments'"
      REASON = 'reason'
      REASON_CODE = 'reason_code'
      COMMENT = 'comment'

      def index
        appointments[:data].each do |appt|
          if include_params[:facilities] && appt[:location_id].present? && appt[:location].nil?
            appt[:location] = FACILITY_ERROR_MSG
          end
          scrape_appt_comments_and_log_details(appt, index_method_logging_name, PAP_COMPLIANCE_TELE)
          log_appt_creation_time(appt)
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
          clinic = mobile_facility_service.get_clinic(appointment[:location_id], appointment[:clinic])
          appointment[:service_name] = clinic&.[](:service_name)
          appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          appointment[:friendly_name] = clinic&.[](:service_name) if clinic&.[](:service_name)
        end

        add_location(appointment)

        scrape_appt_comments_and_log_details(appointment, show_method_logging_name, PAP_COMPLIANCE_TELE)
        log_appt_creation_time(appointment)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointment, 'appointments')
        render json: { data: serialized }
      end

      def create
        new_appointment

        unless new_appointment[:clinic].nil? || new_appointment[:location_id].nil?
          clinic = mobile_facility_service.get_clinic(new_appointment[:location_id], new_appointment[:clinic])
          new_appointment[:service_name] = clinic&.[](:service_name)
          new_appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          new_appointment[:friendly_name] = clinic&.[](:service_name) if clinic&.[](:service_name)
        end

        add_location(new_appointment)

        scrape_appt_comments_and_log_details(new_appointment, create_method_logging_name, PAP_COMPLIANCE_TELE)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointments')
        render json: { data: serialized }, status: :created
      end

      def update
        updated_appointment
        unless updated_appointment[:clinic].nil? || updated_appointment[:location_id].nil?
          clinic = mobile_facility_service.get_clinic(updated_appointment[:location_id], updated_appointment[:clinic])
          updated_appointment[:service_name] = clinic&.[](:service_name)
          updated_appointment[:physical_location] = clinic&.[](:physical_location) if clinic&.[](:physical_location)
          updated_appointment[:friendly_name] = clinic&.[](:service_name) if clinic&.[](:service_name)
        end

        add_location(updated_appointment)

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

      def add_location(appointment)
        return if appointment[:location_id].nil?

        appointment[:location] = mobile_facility_service.get_facility(appointment[:location_id]) || FACILITY_ERROR_MSG
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
        appointments_service.post_appointment(create_params)
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

      def log_appt_creation_time(appt)
        if appt.nil? || appt[:created].nil?
          Rails.logger.info('VAOS::V2::AppointmentsController appointment creation time: unknown')
        else
          creation_time = appt[:created]
          Rails.logger.info("VAOS::V2::AppointmentsController appointment creation time: #{creation_time}",
                            { created: creation_time }.to_json)
        end
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
          clinics: ActiveModel::Type::Boolean.new.deserialize(included&.include?('clinics')),
          facilities: ActiveModel::Type::Boolean.new.deserialize(included&.include?('facilities'))
        }
      end

      def statuses
        s = params[:statuses]
        s.is_a?(Array) ? s.to_csv(row_sep: nil) : s
      end

      def appointment_id
        params[:appointment_id]
      end

      def index_method_logging_name
        if Flipper.enabled?(:va_online_scheduling_use_vpg)
          APPT_INDEX_VPG
        else
          APPT_INDEX_VAOS
        end
      end

      def show_method_logging_name
        if Flipper.enabled?(:va_online_scheduling_use_vpg)
          APPT_SHOW_VPG
        else
          APPT_SHOW_VAOS
        end
      end

      def create_method_logging_name
        if Flipper.enabled?(:va_online_scheduling_use_vpg) && Flipper.enabled?(:va_online_scheduling_enable_OH_requests)
          APPT_CREATE_VPG
        else
          APPT_CREATE_VAOS
        end
      end
    end
  end
end
