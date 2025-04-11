# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::BaseController # rubocop:disable Metrics/ClassLength
      before_action :authorize_with_facilities

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
      CACHE_ERROR_MSG = 'Error fetching referral data from cache'
      PROVIDER_SLOTS_ERROR_MSG = 'Error fetching provider slots'

      rescue_from Redis::BaseError, with: :handle_redis_error

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
          StatsDMetric.new(key: STATSD_KEY).save
          StatsD.increment(STATSD_KEY, tags: ["failures:#{appointments[:meta][:failures]}"])
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
        referral_id = draft_params[:referral_id]
        # TODO: validate referral_id and other needed referral data from the cache from prior referrals response

        cached_referral_data = eps_redis_client.fetch_referral_attributes(referral_number: referral_id)

        referral_validation = check_referral_data_validation(cached_referral_data)
        unless referral_validation[:success]
          render json: referral_validation[:json], status: referral_validation[:status] and return
        end

        referral_usage = check_referral_usage(referral_id)
        render json: referral_usage[:json], status: referral_usage[:status] and return unless referral_usage[:success]

        draft_appointment = eps_appointment_service.create_draft_appointment(referral_id:)
        provider = eps_provider_service.get_provider_service(provider_id: cached_referral_data[:provider_id])

        response_data = OpenStruct.new(
          id: draft_appointment.id,
          provider:,
          slots: fetch_provider_slots(cached_referral_data),
          drive_time: fetch_drive_times(provider)
        )

        serialized = Eps::DraftAppointmentSerializer.new(response_data)
        render json: serialized, status: :created
      end

      def update
        updated_appointment
        set_facility_error_msg(updated_appointment)

        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(updated_appointment, 'appointments')
        render json: { data: serialized }
      end

      def submit_referral_appointment
        params = submit_params
        appointment = eps_appointment_service.submit_appointment(
          params[:id],
          { referral_number: params[:referral_number],
            network_id: params[:network_id],
            provider_service_id: params[:provider_service_id],
            slot_ids: [params[:slot_id]],
            additional_patient_attributes: patient_attributes(params) }
        )

        render json: Eps::DraftAppointmentSerializer.new(appointment), status: :created
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

      ##
      # Lazily initializes and returns an instance of {Eps::RedisClient}.
      # Ensures a single instance is used within the service to interact with Redis.
      #
      # @return [Eps::RedisClient] Memoized instance of the Redis client.
      #
      def eps_redis_client
        @eps_redis_client ||= Eps::RedisClient.new
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
        params.require(:referral_id)
        params.permit(
          :referral_id
        )
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
          },
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
          }
        }
      end

      # Fetches available provider slots using referral data.
      #
      # @param referral_data [Hash] Includes:
      #   - `:provider_id` [String] The provider's ID.
      #   - `:appointment_type_id` [String] The appointment type.
      #   - `:start_date` [String] The earliest appointment date (ISO 8601).
      #   - `:end_date` [String] The latest appointment date (ISO 8601).
      #
      # @return [Array, nil] Available slots array or nil if error occurs
      #
      def fetch_provider_slots(referral_data)
        eps_provider_service.get_provider_slots(
          referral_data[:provider_id],
          {
            appointmentTypeId: referral_data[:appointment_type_id],
            startOnOrAfter: referral_data[:start_date],
            startBefore: referral_data[:end_date]
          }
        )
      end

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
        check = appointments_service.referral_appointment_already_exists?(referral_id, pagination_params)

        if check[:error]
          { success: false, json: { message: "Error checking appointments: #{check[:failures]}" },
            status: :bad_gateway }
        elsif check[:exists]
          { success: false, json: { message: 'No new appointment created: referral is already used' },
            status: :unprocessable_entity }
        else
          { success: true }
        end
      end

      ##
      # Handles Redis connection and operational errors throughout the controller.
      # Provides a consistent error response when Redis is unavailable or operations fail.
      #
      # @param error [Redis::BaseError] The Redis exception that was raised
      # @return [void]
      # @see Redis::BaseError
      def handle_redis_error(error)
        Rails.logger.error("Redis error: #{error.message}")
        StatsD.increment("#{STATSD_KEY}.redis_error")
        render json: { errors: [{ title: CACHE_ERROR_MSG, detail: 'Unable to connect to cache service' }] },
               status: :bad_gateway
      end

      ##
      # Validates that all required referral data attributes are present
      #
      # @param referral_data [Hash, nil] The referral data from the cache
      # @return [Hash] Hash with :valid boolean and :missing_attributes array
      def validate_referral_data(referral_data)
        return { valid: false, missing_attributes: ['all required attributes'] } if referral_data.nil?

        required_attributes = %i[provider_id appointment_type_id start_date end_date]
        missing_attributes = required_attributes.select { |attr| referral_data[attr].blank? }

        {
          valid: missing_attributes.empty?,
          missing_attributes: missing_attributes.map(&:to_s).join(', ')
        }
      end

      ##
      # Validates referral data and builds a formatted response object
      #
      # @param referral_data [Hash, nil] The referral data from the cache
      # @return [Hash] Result hash:
      #   - If data is valid: { success: true }
      #   - If data is invalid: { success: false, json: { errors: [...] }, status: :unprocessable_entity }
      def check_referral_data_validation(referral_data)
        validation_result = validate_referral_data(referral_data)
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
      # Fetches provider slots and builds a formatted response object
      #
      # @param referral_data [Hash] The referral data containing appointment details
      # @return [Hash] Result hash:
      #   - If slots are retrieved: { success: true, slots: [...] }
      #   - If slots cannot be retrieved: { success: false, json: { errors: [...] }, status: :bad_gateway }
      def build_provider_slots_response(referral_data)
        slots = fetch_provider_slots(referral_data)
        if slots.nil?
          {
            success: false,
            json: {
              errors: [{
                title: PROVIDER_SLOTS_ERROR_MSG,
                detail: 'Unable to retrieve available appointment slots'
              }]
            },
            status: :bad_gateway
          }
        else
          { success: true, slots: }
        end
      end
    end
  end
end
