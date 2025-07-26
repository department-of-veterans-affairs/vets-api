# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::BaseController # rubocop:disable Metrics/ClassLength
      before_action :authorize_with_facilities

      PARTIAL_RESPONSE_METRIC = 'api.vaos.va_mobile.response.partial'
      APPT_DRAFT_CREATION_SUCCESS_METRIC = 'api.vaos.appointment_draft_creation.success'
      APPT_DRAFT_CREATION_FAILURE_METRIC = 'api.vaos.appointment_draft_creation.failure'
      APPT_CREATION_SUCCESS_METRIC = 'api.vaos.appointment_creation.success'
      APPT_CREATION_FAILURE_METRIC = 'api.vaos.appointment_creation.failure'
      APPT_CREATION_DURATION_METRIC = 'api.vaos.appointment_creation.duration'
      REFERRAL_DRAFT_STATIONID_METRIC = 'api.vaos.referral_draft_station_id.access'
      PROVIDER_DRAFT_NETWORK_ID_METRIC = 'api.vaos.provider_draft_network_id.access'
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
      CC_APPOINTMENTS = 'Community Care Appointments'

      def index
        appointments[:data].each do |appt|
          set_facility_error_msg(appt) if include_index_params[:facilities]
          scrape_appt_comments_and_log_details(appt, index_method_logging_name, PAP_COMPLIANCE_TELE)
          log_appt_creation_time(appt)
        end

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointments[:data], 'appointments')

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

        begin
          draft_appt = VAOS::V2::EpsDraftAppointment.new(current_user, referral_id, referral_consult_id)

          if draft_appt.error
            StatsD.increment(APPT_DRAFT_CREATION_FAILURE_METRIC, tags: ['service:community_care_appointments'])
            render json: { errors: [{ title: 'Appointment creation failed', detail: draft_appt.error[:message] }] },
                   status: draft_appt.error[:status]
          else
            StatsD.increment(APPT_DRAFT_CREATION_SUCCESS_METRIC, tags: ['service:community_care_appointments'])
            ccra_referral_service.clear_referral_cache(referral_id, current_user.icn)
            render json: Eps::DraftAppointmentSerializer.new(draft_appt), status: :created
          end
        rescue => e
          StatsD.increment(APPT_DRAFT_CREATION_FAILURE_METRIC, tags: ['service:community_care_appointments'])
          handle_appointment_creation_error(e)
        end
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
        submit_args = { referral_number: submit_params[:referral_number],
                        network_id: submit_params[:network_id],
                        provider_service_id: submit_params[:provider_service_id],
                        slot_ids: [submit_params[:slot_id]] }

        if patient_attributes(submit_params).present?
          submit_args[:additional_patient_attributes] = patient_attributes(submit_params)
        end

        appointment = eps_appointment_service.submit_appointment(submit_params[:id], submit_args)

        if appointment[:error]
          StatsD.increment(APPT_CREATION_FAILURE_METRIC,
                           tags: ['service:community_care_appointments', "error_type:#{appointment[:error]}"])
          return render(json: submission_error_response(appointment[:error]), status: :conflict)
        end

        log_referral_booking_duration(submit_params[:referral_number])

        StatsD.increment(APPT_CREATION_SUCCESS_METRIC, tags: ['service:community_care_appointments'])
        render json: { data: { id: appointment.id } }, status: :created
      rescue => e
        StatsD.increment(APPT_CREATION_FAILURE_METRIC, tags: ['service:community_care_appointments'])
        handle_appointment_creation_error(e)
      end

      private

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
          travel_pay_claims: ActiveModel::Type::Boolean.new.deserialize(included&.include?('travel_pay_claims'))
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
        if Flipper.enabled?(:va_online_scheduling_use_vpg) && Flipper.enabled?(:va_online_scheduling_OH_request)
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
      # Searches for a provider using the NPI from the referral data.
      #
      # @param npi [String] The National Provider Identifier (NPI) to search for
      # @param specialty [String] The specialty to search for
      # @param address [Hash] The address to search for
      # @return [Object, nil] The provider service object if found, nil otherwise
      #
      def find_provider(npi:, specialty:, address:)
        eps_provider_service.search_provider_services(npi:, specialty:, address:)
      end

      ##
      # Constructs a response object for a draft appointment with associated provider,
      # slots, and drive time information.
      #
      # @param draft_appointment [Object] The draft appointment object containing the appointment ID
      # @param provider [Object] The provider object associated with the appointment
      # @param slots [Object] The available appointment slots for the provider
      # @param drive_time [Object, nil] The calculated drive time to the provider's location, if available
      # @return [OpenStruct] A structured response containing:
      #   - id [String] The draft appointment ID
      #   - provider [Object] The provider details
      #   - slots [Object] Available appointment slots
      #   - drive_time [Object, nil] Drive time information
      #
      def build_draft_response(draft_appointment, provider, slots, drive_time)
        OpenStruct.new(
          id: draft_appointment.id,
          provider:,
          slots:,
          drive_time:
        )
      end

      # Fetches available provider slots using referral data.
      #
      # @param referral [ReferralDetail] The referral object containing:
      #   - `provider_npi` [String] The provider's NPI.
      #   - `referral_date` [String] The earliest appointment date (ISO 8601).
      #   - `expiration_date` [String] The latest appointment date (ISO 8601).
      # @param provider [Object] The provider object.
      #
      # @return [Array, nil] Available slots array or nil if error occurs
      #
      def fetch_provider_slots(referral, provider, draft_appointment_id)
        appointment_type_id = get_provider_appointment_type_id(provider)
        eps_provider_service.get_provider_slots(
          provider.id,
          {
            appointmentTypeId: appointment_type_id,
            startOnOrAfter: [Date.parse(referral.referral_date), Date.current].max.to_time(:utc).iso8601,
            startBefore: Date.parse(referral.expiration_date).to_time(:utc).iso8601,
            appointmentId: draft_appointment_id
          }
        )
      rescue ArgumentError
        Rails.logger.error("#{CC_APPOINTMENTS}: Error fetching provider slots")
        nil
      end

      ##
      # Retrieves the appointment type ID for the first self-schedulable appointment type.
      #
      # @param provider [Object] The provider object containing appointment_types
      # @return [String] The ID of the first self-schedulable appointment type
      # @raise [Common::Exceptions::BackendServiceException] If provider appointment types are missing
      #   or no self-schedulable types are available
      #
      def get_provider_appointment_type_id(provider)
        # Validate provider appointment types data before accessing it
        if provider.appointment_types.blank?
          raise Common::Exceptions::BackendServiceException.new(
            'PROVIDER_APPOINTMENT_TYPES_MISSING',
            {},
            502,
            'Provider appointment types data is not available'
          )
        end

        # Filter for self-schedulable appointment types
        self_schedulable_types = provider.appointment_types.select { |apt| apt[:is_self_schedulable] == true }

        if self_schedulable_types.blank?
          raise Common::Exceptions::BackendServiceException.new(
            'PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING',
            {},
            502,
            'No self-schedulable appointment types available for this provider'
          )
        end

        self_schedulable_types.first[:id]
      end

      ##
      # Builds a standardized error response for draft appointment creation failures.
      #
      # This method returns a formatted error response hash using the
      # {#appt_creation_failed_error} helper, with a specific title and detail
      # message indicating that an unexpected error occurred while creating the
      # draft appointment.
      #
      # @return [Hash] Formatted error response for draft appointment creation failure
      #
      def draft_appointment_creation_failed_error
        appt_creation_failed_error(
          title: 'Appointment creation failed',
          detail: 'An unexpected error occurred while creating the draft appointment'
        )
      end

      ##
      # Fetches drive time information from the user's residential address to the provider's location.
      # Uses the EPS provider service to calculate drive times between the current user's address
      # and the specified provider's coordinates.
      #
      # @param provider [Object] The provider object containing location data with latitude and longitude
      # @return [Object, nil] Drive time response object from EPS service, or nil if user address
      #   coordinates are not available
      #
      def fetch_drive_times(provider)
        user_address = current_user.vet360_contact_info&.residential_address

        return nil unless user_address&.latitude && user_address.longitude

        eps_provider_service.get_drive_times(
          destinations: {
            provider.id => {
              latitude: provider.location[:latitude],
              longitude: provider.location[:longitude]
            }
          },
          origin: {
            latitude: user_address.latitude,
            longitude: user_address.longitude
          }
        )
      end

      ##
      # Checks if a referral is already in use by cross referrencing referral number against complete
      # list of existing appointments
      #
      # @param referral_id [String] the referral number to check.
      # @return [Hash] Result hash:
      #   - If referral is unused: { success: true }
      #   - If an error occurs: { success: false, json: { message: ... }, status: :bad_gateway }
      #   - If referral exists: { success: false, json: { message: ... }, status: :unprocessable_entity }
      #
      # TODO: pass in date from cached referral data to use as range for CCRA appointments call
      def check_referral_usage(referral_id)
        check = appointments_service.referral_appointment_already_exists?(referral_id)

        return referral_check_error_response(check[:failures]) if check[:error]
        return referral_already_used_response if check[:exists]

        { success: true }
      end

      def referral_check_error_response(failures)
        {
          success: false,
          json: {
            errors: [{
              title: 'Appointment creation failed',
              detail: "Error checking existing appointments: #{failures}"
            }]
          },
          status: :bad_gateway
        }
      end

      def referral_already_used_response
        {
          success: false,
          json: {
            errors: [{
              title: 'Appointment creation failed',
              detail: 'No new appointment created: referral is already used'
            }]
          },
          status: :unprocessable_entity
        }
      end

      ##
      # Handles Redis connection and operational errors throughout the controller.
      # Provides a consistent error response when Redis is unavailable or operations fail.
      #
      # @param error [Redis::BaseError] The Redis exception that was raised
      # @return [void]
      # @see Redis::BaseError
      def handle_redis_error(error)
        Rails.logger.error("#{CC_APPOINTMENTS}: #{error.class}}")
        render json: { errors: [{ title: 'Appointment creation failed', detail: 'Redis connection error' }] },
               status: :bad_gateway
      end

      ##
      # Validates that all required referral data attributes are present
      #
      # @param referral [ReferralDetail, nil] The referral object
      # @return [Hash] Hash with :valid boolean and :missing_attributes array
      def validate_referral_data(referral)
        return { valid: false, missing_attributes: ['all required attributes'] } if referral.nil?

        required_attributes = {
          'provider_npi' => referral.provider_npi,
          'referral_date' => referral.referral_date,
          'expiration_date' => referral.expiration_date
        }

        missing_attributes = required_attributes.select { |_, value| value.blank? }.keys

        {
          valid: missing_attributes.empty?,
          missing_attributes: missing_attributes.join(', ')
        }
      end

      ##
      # Validates referral data and builds a formatted response object
      #
      # @param referral [ReferralDetail, nil] The referral object
      # @return [Hash] Result hash:
      #   - If data is valid: { success: true }
      #   - If data is invalid: { success: false, json: { errors: [...] }, status: :unprocessable_entity }
      def check_referral_data_validation(referral)
        validation_result = validate_referral_data(referral)
        if validation_result[:valid]
          { success: true }
        else
          missing_attributes = validation_result[:missing_attributes]
          {
            success: false,
            json: {
              errors: [{
                title: 'Invalid referral data',
                detail: "Required referral data is missing or incomplete: #{missing_attributes}"
              }]
            },
            status: :unprocessable_entity
          }
        end
      end

      ##
      # Validates that a provider is present and has a valid ID
      #
      # @param provider [Object, nil] The provider object to validate
      # @param referral [ReferralDetail] The referral object containing provider details for logging
      # @return [Hash] Result hash:
      #   - If provider is valid: { success: true }
      #   - If provider is invalid: { success: false, json: error_response, status: :not_found }
      def check_provider_validity(provider, referral)
        if provider&.id.blank?
          Rails.logger.error("#{CC_APPOINTMENT_ERROR_TAG}: Provider not found while creating draft appointment.",
                             { provider_address: referral.treating_facility_address,
                               provider_npi: referral.provider_npi,
                               provider_specialty: referral.provider_specialty,
                               tag: CC_APPOINTMENT_ERROR_TAG })
          { success: false, json: provider_not_found_error, status: :not_found }
        else
          { success: true }
        end
      end

      ##
      # Formats a standardized error response when a provider cannot be found
      #
      # @return [Hash] Error object with title and detail for JSON rendering
      #
      def provider_not_found_error
        appt_creation_failed_error(
          title: 'Appointment creation failed',
          detail: 'Provider not found'
        )
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
        Rails.logger.error("#{CC_APPOINTMENTS}: Appointment creation error: #{e.class}")
        original_status = e.respond_to?(:original_status) ? e.original_status : nil
        status_code = appointment_error_status(original_status)
        render(json: appt_creation_failed_error(error: e, status: original_status), status: status_code)
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

      ##
      # Processes the creation of a draft appointment by orchestrating multiple service calls.
      # Validates referral data, checks for existing appointments, finds providers, and builds
      # the complete draft appointment response with associated data.
      #
      # @param referral_id [String] The referral number to process
      # @param referral_consult_id [String] The referral consult ID for data retrieval
      # @return [Hash] Result hash with success status and data or error information
      #   - If successful: { success: true, data: draft_response_object }
      #   - If failed: { success: false, json: error_response, status: http_status }
      #
      def process_draft_appointment(referral_id, referral_consult_id)
        referral = ccra_referral_service.get_referral(referral_consult_id, current_user.icn)
        log_referral_metrics(referral)
        validation = check_referral_data_validation(referral)
        return validation unless validation[:success]

        usage = check_referral_usage(referral_id)
        return usage unless usage[:success]

        provider_result = find_and_validate_provider(referral)
        return provider_result unless provider_result[:success]

        provider = provider_result[:provider]
        log_provider_metrics(provider)

        draft = eps_appointment_service.create_draft_appointment(referral_id:)
        unless draft.id
          return { success: false, json: draft_appointment_creation_failed_error, status: unprocessable_entity }
        end

        # Bypass drive time calculation if EPS mocks are enabled since we don't have betamocks for vets360
        drive_time = fetch_drive_times(provider) unless eps_appointment_service.config.mock_enabled?
        slots = fetch_provider_slots(referral, provider, draft.id)

        { success: true, data: build_draft_response(draft, provider, slots, drive_time) }
      end

      ##
      # Logs referral provider metrics for tracking and monitoring
      #
      # @param referral [ReferralDetail] The referral object containing provider information
      # @return [void]
      #
      def log_referral_metrics(referral)
        referring_provider_id = sanitize_log_value(referral.referring_facility_code)
        referral_provider_id = sanitize_log_value(referral.provider_npi)

        StatsD.increment(REFERRAL_DRAFT_STATIONID_METRIC, tags: [
                           'service:community_care_appointments',
                           "referring_provider_id:#{referring_provider_id}",
                           "referral_provider_id:#{referral_provider_id}"
                         ])
      end

      ##
      # Finds and validates a provider based on referral information
      #
      # @param referral [ReferralDetail] The referral object containing provider search criteria
      # @return [Hash] Result hash with success status and provider data or error information
      #   - If successful: { success: true, provider: provider_object }
      #   - If failed: { success: false, json: error_response, status: http_status }
      #
      def find_and_validate_provider(referral)
        provider = find_provider(npi: referral.provider_npi,
                                 specialty: referral.provider_specialty,
                                 address: referral.treating_facility_address)

        if provider&.id.blank?
          log_provider_not_found_error(referral)
          return { success: false, json: provider_not_found_error, status: :not_found }
        end

        { success: true, provider: }
      end

      ##
      # Logs provider not found error with relevant details
      #
      # @param referral [ReferralDetail] The referral object containing provider information
      # @return [void]
      #
      def log_provider_not_found_error(referral)
        Rails.logger.error("#{CC_APPOINTMENTS}: Provider not found while creating draft appointment.",
                           { provider_address: referral.treating_facility_address,
                             provider_npi: referral.provider_npi,
                             provider_specialty: referral.provider_specialty,
                             tag: CC_APPOINTMENTS })
      end

      ##
      # Logs provider network metrics for tracking
      #
      # @param provider [Object] The provider object containing network information
      # @return [void]
      #
      def log_provider_metrics(provider)
        return if provider&.network_ids.blank?

        provider.network_ids.each do |network_id|
          StatsD.increment(PROVIDER_DRAFT_NETWORK_ID_METRIC,
                           tags: ['service:community_care_appointments', "network_id:#{network_id}"])
        end
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
        StatsD.histogram(APPT_CREATION_DURATION_METRIC, duration, tags: ['service:community_care_appointments'])
      end

      # Sanitizes log values by removing spaces and providing fallback for nil/empty values
      # @param value [String, nil] the value to sanitize
      # @return [String] sanitized value or "no_value" if blank
      def sanitize_log_value(value)
        return 'no_value' if value.blank?

        value.to_s.gsub(/\s+/, '_')
      end
    end
  end
end
