# frozen_string_literal: true

require 'common/exceptions'
require 'unique_user_events'

module VAOS
  module V2
    class AppointmentsController < VAOS::BaseController # rubocop:disable Metrics/ClassLength
      before_action :authorize_with_facilities

      include VAOS::CommunityCareConstants

      # Local constants for this controller
      PARTIAL_RESPONSE_METRIC = 'api.vaos.va_mobile.response.partial'
      APPT_DRAFT_CREATION_SUCCESS_METRIC = "#{STATSD_PREFIX}.appointment_draft_creation.success".freeze
      APPT_DRAFT_CREATION_FAILURE_METRIC = "#{STATSD_PREFIX}.appointment_draft_creation.failure".freeze
      APPT_CREATION_SUCCESS_METRIC = "#{STATSD_PREFIX}.appointment_creation.success".freeze
      APPT_CREATION_FAILURE_METRIC = "#{STATSD_PREFIX}.appointment_creation.failure".freeze
      APPT_CREATION_DURATION_METRIC = "#{STATSD_PREFIX}.appointment_creation.duration".freeze
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
      CACHE_ERROR_MSG = 'Error fetching referral data from cache'

      def index
        appointments[:data].each do |appt|
          set_facility_error_msg(appt) if include_index_params[:facilities]
          scrape_appt_comments_and_log_details(appt, index_method_logging_name, PAP_COMPLIANCE_TELE)
          log_appt_creation_time(appt)
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointments[:data], 'appointments')

        # Log unique user event for appointments accessed (with facility tracking for OH events)
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::APPOINTMENTS_ACCESSED,
          event_facility_ids: appointment_facility_ids(appointments[:data])
        )

        if appointments[:meta][:failures] && appointments[:meta][:failures].empty?
          render json: { data: serialized, meta: appointments[:meta] }, status: :ok
        else
          StatsDMetric.new(key: PARTIAL_RESPONSE_METRIC).save
          StatsD.increment(PARTIAL_RESPONSE_METRIC, tags: ["failures:#{appointments[:meta][:failures]}"])
          render json: { data: serialized, meta: appointments[:meta] }, status: :multi_status
        end
      end

      def show
        appointment = appointment_show_params[:_include] == 'eps' ? eps_appointment : vaos_appointment

        set_facility_error_msg(appointment)

        scrape_appt_comments_and_log_details(appointment, show_method_logging_name, PAP_COMPLIANCE_TELE)
        log_appt_creation_time(appointment)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointment, 'appointments')
        render json: { data: serialized }
      end

      def create
        new_appointment
        set_facility_error_msg(new_appointment)

        scrape_appt_comments_and_log_details(new_appointment, create_method_logging_name, PAP_COMPLIANCE_TELE)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointments')
        render json: { data: serialized }, status: :created
      end

      def create_draft
        referral_id = draft_params[:referral_number]
        referral_consult_id = draft_params[:referral_consult_id]
        draft_appt = VAOS::V2::CreateEpsDraftAppointment.call(current_user, referral_id, referral_consult_id)

        if draft_appt.error
          render json: { errors: [{ title: 'Appointment creation failed', detail: draft_appt.error[:message] }] },
                 status: draft_appt.error[:status]
        else
          ccra_referral_service.clear_referral_cache(referral_id, current_user.icn)
          render json: Eps::DraftAppointmentSerializer.new(draft_appt), status: :created
        end
      rescue Redis::BaseError => e
        handle_redis_error(e)
      rescue => e
        handle_appointment_creation_error(e)
      end

      def update
        updated_appointment
        set_facility_error_msg(updated_appointment)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(updated_appointment, 'appointments')
        render json: { data: serialized }
      end

      ##
      # Submits a referral appointment to the EPS service for final scheduling.
      # Validates the appointment response and handles various error conditions.
      #
      # The method processes appointment submission parameters, calls the EPS service,
      # and performs validation on the returned appointment data.
      #
      # @return [void] Renders JSON response with appointment ID on success,
      #   or error response on failure
      # @raise [StandardError] For any unexpected errors during submission
      #
      def submit_referral_appointment
        type_of_care = 'no_value'
        begin
          type_of_care = get_type_of_care_for_metrics(submit_params[:referral_number])
        rescue
          Rails.logger.error('Failed to retrieve type of care for metrics')
        end

        submit_args = build_submit_args
        appointment = eps_appointment_service.submit_appointment(submit_params[:id], submit_args)

        if appointment[:error]
          record_appt_metric(APPT_CREATION_FAILURE_METRIC, type_of_care)
          return render(json: submission_error_response(appointment[:error]), status: :conflict)
        end

        log_referral_booking_duration(submit_params[:referral_number])
        record_appt_metric(APPT_CREATION_SUCCESS_METRIC, type_of_care)
        render json: { data: { id: appointment.id } }, status: :created
      rescue => e
        record_appt_metric(APPT_CREATION_FAILURE_METRIC, type_of_care)
        handle_appointment_creation_error(e)
      end

      def get_avs_binaries
        render json: VAOS::V2::AvsBinarySerializer.new(avs_binaries), status: :ok
      end

      private

      # Extract unique facility IDs (3-character) from user-visible appointments for OH event tracking
      # Only includes appointments that are future, past, or pending (shown to users in the UI)
      # Note: location_id may be a sta6aid (5-6 characters like "983GC") - we extract only the
      # 3-character facility ID prefix to match against TRACKED_FACILITY_IDS
      # Returns nil if mhv_oh_unique_user_metrics_logging_appt feature flag is disabled
      # @param appointments [Array] list of appointment hashes/objects
      # @return [Array<String>, nil] unique 3-character facility IDs or nil if none/disabled
      def appointment_facility_ids(appointments)
        return nil unless Flipper.enabled?(:mhv_oh_unique_user_metrics_logging_appt)

        visible_appointments = appointments.select do |appt|
          # Pending appointments are always visible; non-cancelled appointments with date flags are visible
          appt[:pending] || (appt[:status] != 'cancelled' && (appt[:future] || appt[:past]))
        end
        station_ids = visible_appointments.filter_map { |appt| appt[:location_id]&.[](0..2) }.uniq
        station_ids.presence
      end

      def set_facility_error_msg(appointment)
        appointment[:location] = FACILITY_ERROR_MSG if appointment[:location_id].present? && appointment[:location].nil?
      end

      def appointments_service
        @appointments_service ||=
          VAOS::V2::AppointmentsService.new(current_user)
      end

      def mobile_facility_service
        @mobile_facility_service ||=
          VAOS::V2::MobileFacilityService.new(current_user)
      end

      def eps_appointment_service
        @eps_appointment_service ||=
          Eps::AppointmentService.new(current_user)
      end

      def eps_provider_service
        @eps_provider_service ||=
          Eps::ProviderService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, statuses, pagination_params, include_index_params)
      end

      def vaos_appointment
        @appointment ||=
          appointments_service.get_appointment(appointment_id, include_show_params)
      end

      def eps_appointment
        @eps_appointment ||=
          eps_appointment_service.get_appointment(appointment_id:, retrieve_latest_details: true)
      end

      def new_appointment
        @new_appointment ||= get_new_appointment
      end

      def updated_appointment
        @updated_appointment ||=
          appointments_service.update_appointment(update_appt_id, status_update)
      end

      def avs_binaries
        @avs_binaries ||=
          appointments_service.fetch_avs_binaries(avs_binaries_params[:appointment_id],
                                                  avs_binaries_params[:doc_ids].split(','))
      end

      # Makes a call to the VAOS service to create a new appointment.
      def get_new_appointment
        appointments_service.post_appointment(create_params)
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

      def appointment_index_params
        params.require(:start)
        params.require(:end)
        params.permit(:start, :end, :_include)
      end

      def appointment_show_params
        params.permit(:_include)
      end

      def draft_params
        params.require(:referral_number)
        params.require(:referral_consult_id)
        params.permit(:referral_number, :referral_consult_id)
      end

      def avs_binaries_params
        params.require(:appointment_id)
        params.require(:doc_ids)
        params.permit(:appointment_id, :doc_ids)
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
        DateTime.parse(appointment_index_params[:start]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start', params[:start])
      end

      def end_date
        DateTime.parse(appointment_index_params[:end]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end', params[:end])
      end

      def include_index_params
        included = appointment_index_params[:_include]&.split(',')
        {
          clinics: ActiveModel::Type::Boolean.new.deserialize(included&.include?('clinics')),
          facilities: ActiveModel::Type::Boolean.new.deserialize(included&.include?('facilities')),
          avs: ActiveModel::Type::Boolean.new.deserialize(included&.include?('avs')),
          travel_pay_claims: ActiveModel::Type::Boolean.new.deserialize(included&.include?('travel_pay_claims')),
          eps: ActiveModel::Type::Boolean.new.deserialize(included&.include?('eps'))
        }
      end

      def include_show_params
        included = appointment_show_params[:_include]&.split(',')
        {
          avs: ActiveModel::Type::Boolean.new.deserialize(included&.include?('avs')),
          travel_pay_claims: ActiveModel::Type::Boolean.new.deserialize(included&.include?('travel_pay_claims'))
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
        if Flipper.enabled?(:va_online_scheduling_use_vpg)
          APPT_CREATE_VPG
        else
          APPT_CREATE_VAOS
        end
      end

      def submit_params
        params.require(%i[id network_id provider_service_id slot_id referral_number])
        params.permit(
          :id,
          :network_id,
          :provider_service_id,
          :slot_id,
          :referral_number,
          :birth_date,
          :email,
          :phone_number,
          :gender,
          address: submit_address_params,
          name: [
            :family,
            { given: [] }
          ]
        )
      end

      def submit_address_params
        [
          :type,
          { line: [] },
          :city,
          :state,
          :postal_code,
          :country,
          :text
        ]
      end

      def patient_attributes(params)
        {
          name: {
            family: params.dig(:name, :family),
            given: params.dig(:name, :given)
          }.compact.presence,
          phone: params[:phone_number],
          email: params[:email],
          birth_date: params[:birth_date],
          gender: params[:gender],
          address: {
            line: params.dig(:address, :line),
            city: params.dig(:address, :city),
            state: params.dig(:address, :state),
            country: params.dig(:address, :country),
            postal_code: params.dig(:address, :postal_code),
            type: params.dig(:address, :type)
          }.compact.presence
        }.compact
      end

      ##
      # Handles Redis connection and operational errors throughout the controller.
      # Provides a consistent error response when Redis is unavailable or operations fail.
      #
      # @param error [Redis::BaseError] The Redis exception that was raised
      # @return [void]
      # @see Redis::BaseError
      def handle_redis_error(error)
        error_data = {
          error_class: error.class.name,
          error_message: error.message,
          user_uuid: current_user&.uuid
        }
        Rails.logger.error("#{CC_APPOINTMENTS}: Redis error", error_data)
        render json: { errors: [{ title: 'Appointment creation failed', detail: 'Redis connection error' }] },
               status: :bad_gateway
      end

      ##
      # Gets a CCRA referral service instance
      #
      # @return [Ccra::ReferralService] The CCRA referral service
      def ccra_referral_service
        @ccra_referral_service ||= Ccra::ReferralService.new(current_user)
      end

      ##
      # Maps appointment error codes to appropriate HTTP status codes
      # This method handles string error codes from appointment responses
      #
      # @param error_code [String] The error code from the appointment response
      # @return [Symbol] The corresponding HTTP status code symbol
      #
      def appointment_error_status(error_code)
        case error_code
        when 'not-found', 404
          :not_found # 404
        when 'conflict', 409
          :conflict # 409
        when 'bad-request', 400
          :bad_request # 400
        when 'internal-error', 500, 502
          :bad_gateway # 502
        else
          # too-far-in-the-future, already-canceled, too-late-to-cancel, etc.
          :unprocessable_entity # 422
        end
      end

      ##
      # Handles appointment-related errors throughout the controller.
      # Maps error codes to appropriate HTTP status codes and renders
      # standardized error responses.
      #
      # @param e [Exception] The exception that was raised
      # @return [void] Renders JSON error response with appropriate HTTP status
      #
      def handle_appointment_creation_error(e)
        error_data = {
          error_class: e.class.name,
          error_message: e.message,
          user_uuid: current_user&.uuid
        }

        Rails.logger.error("#{CC_APPOINTMENTS}: Appointment creation error", error_data)

        if e.is_a?(ActionController::ParameterMissing)
          status_code = :bad_request
        else
          original_status = e.respond_to?(:original_status) ? e.original_status : nil
          status_code = appointment_error_status(original_status)
        end
        render(json: appt_creation_failed_error(error: e, status: status_code), status: status_code)
      end

      ##
      # Formats a standardized error response for appointment creation failures.
      # Extracts error details from exception objects and builds a consistent
      # error structure with metadata for debugging and monitoring.
      #
      # @param error [Exception, nil] The exception that caused the failure
      # @param title [String, nil] Custom error title (defaults to 'Appointment creation failed')
      # @param detail [String, nil] Custom error detail (defaults to 'Could not create appointment')
      # @param status [String, Integer, nil] Status code for error metadata
      # @return [Hash] Formatted error response with title, detail, and metadata
      #
      def appt_creation_failed_error(error: nil, title: nil, detail: nil, status: nil)
        default_title = 'Appointment creation failed'
        default_detail = 'Could not create appointment'
        status_code = error.respond_to?(:original_status) ? error.original_status : status
        {
          errors: [{
            title: title || default_title,
            detail: detail || default_detail,
            meta: {
              original_detail: error.try(:response_values)&.dig(:detail),
              original_error: error.try(:message) || 'Unknown error',
              code: status_code,
              backend_response: error.try(:original_body)
            }
          }]
        }
      end

      ##
      # Builds a standardized error response for appointment submission errors.
      # Used specifically for EPS appointment errors that contain error codes
      # in the appointment response data.
      #
      # @param error_code [String] The error code from the appointment response,
      #   defaults to 'unknown EPS error' if nil
      # @return [Hash] Formatted error response with title, detail, and error code
      #
      def submission_error_response(error_code)
        {
          errors: [{
            title: 'Appointment submission failed',
            detail: "An error occurred: #{error_code}",
            code: error_code
          }]
        }
      end

      # Records the duration between when a referral booking was started and when it completes
      # by measuring the time between the cached start time and current time.
      # The duration is recorded as a StatsD metric in milliseconds.
      #
      # @param referral_number [String] The referral number to lookup the start time for
      # @return [void]
      def log_referral_booking_duration(referral_number)
        start_time = ccra_referral_service.get_booking_start_time(
          referral_number,
          current_user.icn
        )

        return unless start_time

        duration = (Time.current.to_f - start_time) * 1000
        StatsD.histogram(APPT_CREATION_DURATION_METRIC, duration, tags: [COMMUNITY_CARE_SERVICE_TAG])
      end

      ##
      # Builds the arguments hash for submitting an appointment
      #
      # @return [Hash] The arguments for the EPS appointment submission
      def build_submit_args
        args = { referral_number: submit_params[:referral_number],
                 network_id: submit_params[:network_id],
                 provider_service_id: submit_params[:provider_service_id],
                 slot_ids: [submit_params[:slot_id]] }

        patient_attrs = patient_attributes(submit_params)
        args[:additional_patient_attributes] = patient_attrs if patient_attrs.present?
        args
      end

      ##
      # Records an appointment metric with type of care tag
      #
      # @param metric [String] The metric name to record
      # @param type_of_care [String] The type of care value
      def record_appt_metric(metric, type_of_care)
        StatsD.increment(metric, tags: [COMMUNITY_CARE_SERVICE_TAG, "type_of_care:#{type_of_care}"])
      end

      ##
      # Retrieves the type of care for metrics, defaulting to 'no_value' if unavailable
      #
      # @param referral_number [String] The referral number to lookup
      # @return [String] The sanitized type of care, or 'no_value' if not found
      def get_type_of_care_for_metrics(referral_number)
        return 'no_value' if referral_number.blank?

        cached_referral = ccra_referral_service.get_cached_referral_data(referral_number, current_user.icn)
        sanitize_log_value(cached_referral&.category_of_care)
      rescue Redis::BaseError
        'no_value'
      end

      ##
      # Sanitizes values for safe logging and metrics
      # Replaces blank values with 'no_value' and removes whitespace
      #
      # @param value [String, nil] The value to sanitize
      # @return [String] The sanitized value safe for logging
      def sanitize_log_value(value)
        return 'no_value' if value.blank?

        value.to_s.gsub(/\s+/, '_')
      end
    end
  end
end
