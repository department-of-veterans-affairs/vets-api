# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'map/security_token/errors'
require 'json'
require 'memoist'

module VAOS
  module V2
    class AppointmentsService < VAOS::SessionService # rubocop:disable Metrics/ClassLength
      extend Memoist

      DIRECT_SCHEDULE_ERROR_KEY = 'DirectScheduleError'
      AVS_ERROR_MESSAGE = 'Error retrieving AVS link'
      MANILA_PHILIPPINES_FACILITY_ID = '358'

      ORACLE_HEALTH_CANCELLATIONS = :va_online_scheduling_enable_OH_cancellations
      APPOINTMENTS_USE_VPG = :va_online_scheduling_use_vpg
      APPOINTMENTS_OH_REQUESTS = :va_online_scheduling_OH_request
      APPOINTMENTS_OH_DIRECT_SCHEDULE_REQUESTS = :va_online_scheduling_OH_direct_schedule
      APPOINTMENT_TYPES = {
        va: 'VA',
        cc_appointment: 'COMMUNITY_CARE_APPOINTMENT',
        cc_request: 'COMMUNITY_CARE_REQUEST',
        request: 'REQUEST'
      }.freeze

      # Output format for preferred dates
      # Example: "Thu, July 18, 2024 in the ..."
      OUTPUT_FORMAT_AM = '%a, %B %-d, %Y in the morning'
      OUTPUT_FORMAT_PM = '%a, %B %-d, %Y in the afternoon'

      # rubocop:disable Metrics/MethodLength
      def get_appointments(start_date, end_date, statuses = nil, pagination_params = {}, include = {})
        cnp_count = 0

        response = send_appointments_request(start_date, end_date, __method__, pagination_params, statuses)
        return response if response.dig(:meta, :failures)

        appointments = response.body[:data]

        appointments.each do |appt|
          prepare_appointment(appt, include)
          cnp_count += 1 if cnp?(appt)
        end

        appointments = merge_appointments(eps_appointments, appointments) if include[:eps]

        if Flipper.enabled?(:travel_pay_view_claim_details, user) && include[:travel_pay_claims]
          appointments = merge_all_travel_claims(start_date, end_date, appointments)
        end

        if Flipper.enabled?(:appointments_consolidation, user)
          filterer = AppointmentsPresentationFilter.new
          appointments.keep_if { |appt| filterer.user_facing?(appt) }
        end

        # log count of C&P appointments in the appointments list, per GH#78141
        log_cnp_appt_count(cnp_count) if cnp_count.positive?
        {
          data: deserialized_appointments(appointments),
          meta: pagination(pagination_params).merge(partial_errors(response, __method__))
        }
      end

      ##
      # Checks whether a referral has already been used in an existing appointment.
      #
      # This method first retrieves all VAOS appointments using a 200‐year date range via
      # #get_all_appointments. If that response contains any failures, it returns an error hash
      # with the failure messages. If a VAOS appointment is found with a matching referral_id,
      # it returns { exists: true }. Otherwise, it checks the EPS appointments for a matching
      # referral number and returns { exists: true } if found. If no matching appointment is found,
      # it returns { exists: false }.
      #
      # @param referral_id [String] the referral identifier to check.
      # @param pagination_params [Hash] (optional) pagination options (e.g. page and per_page).
      #
      # @return [Hash] a result hash that is one of:
      #   - { error: true, failures: [...] } if an error occurred during the appointment retrieval,
      #   - { exists: true } if an appointment with the given referral exists,
      #   - { exists: false } if no appointment with the referral is found.
      def referral_appointment_already_exists?(referral_id, pagination_params = {})
        vaos_response = get_all_appointments(pagination_params)
        vaos_request_failures = vaos_response[:meta][:failures]

        return { error: true, failures: vaos_request_failures } if vaos_request_failures.present?
        return { exists: true } if vaos_response[:data].any? { |appt| appt[:referral_id] == referral_id }

        eps_appointments = eps_appointments_service.get_appointments[:data]
        return { exists: true } if eps_appointments.any? { |appt| appt[:referral][:referral_number] == referral_id }

        { exists: false }
      end

      # rubocop:enable Metrics/MethodLength
      def get_appointment(appointment_id, include = {})
        params = {}
        with_monitoring do
          response = perform(:get, get_appointment_base_path(appointment_id), params, headers)
          appointment = response.body[:data]
          # We always fetch facility and clinic information when getting a single appointment
          include[:facilities] = true
          include[:clinics] = true

          prepare_appointment(appointment, include)

          if Flipper.enabled?(:travel_pay_view_claim_details, user) && include[:travel_pay_claims]
            appointment = merge_one_travel_claim(appointment)
          end

          OpenStruct.new(appointment)
        end
      end

      # rubocop:disable Metrics/MethodLength
      def post_appointment(request_object_body)
        filtered_reason_code_text = filter_reason_code_text(request_object_body)
        request_object_body[:reason_code][:text] = filtered_reason_code_text if filtered_reason_code_text.present?

        params = VAOS::V2::AppointmentForm.new(user, request_object_body).params.with_indifferent_access
        params.compact_blank!
        with_monitoring do
          response = if params[:status] == 'proposed'
                       create_appointment_request(params)
                     else
                       create_direct_scheduling_appointment(params)
                     end

          if request_object_body[:kind] == 'clinic' &&
             booked?(request_object_body) # a direct scheduled appointment
            modify_desired_date(request_object_body, get_facility_timezone(request_object_body[:location_id]))
          end

          new_appointment = response.body
          convert_appointment_time(new_appointment)
          find_and_merge_provider_name(new_appointment) if cc?(new_appointment)
          extract_appointment_fields(new_appointment)
          merge_clinic(new_appointment)
          merge_facility(new_appointment)
          set_type(new_appointment)
          set_modality(new_appointment)
          set_derived_appointment_date_fields(new_appointment)
          OpenStruct.new(new_appointment)
        rescue Common::Exceptions::BackendServiceException => e
          log_direct_schedule_submission_errors(e) if booked?(params)
          raise e
        end
      end

      def create_direct_scheduling_appointment(params)
        if Flipper.enabled?(APPOINTMENTS_USE_VPG, user) &&
           Flipper.enabled?(APPOINTMENTS_OH_DIRECT_SCHEDULE_REQUESTS, user)
          perform(:post, appointments_base_path_vpg, params, headers)
        else
          perform(:post, appointments_base_path_vaos, params, headers)
        end
      end

      def create_appointment_request(params)
        if Flipper.enabled?(APPOINTMENTS_USE_VPG, user) && Flipper.enabled?(APPOINTMENTS_OH_REQUESTS, user)
          perform(:post, appointments_base_path_vpg, params, headers)
        else
          perform(:post, appointments_base_path_vaos, params, headers)
        end
      end

      # rubocop:enable Metrics/MethodLength
      def update_appointment(appt_id, status)
        with_monitoring do
          if Flipper.enabled?(ORACLE_HEALTH_CANCELLATIONS, user) &&
             Flipper.enabled?(APPOINTMENTS_USE_VPG, user)
            update_appointment_vpg(appt_id, status)
            get_appointment(appt_id)
          else
            response = update_appointment_vaos(appt_id, status).body
            convert_appointment_time(response)
            extract_appointment_fields(response)
            merge_clinic(response)
            merge_facility(response)
            OpenStruct.new(response)
          end
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

      def get_sorted_recent_appointments
        appointments = get_appointments(1.year.ago, Date.current.end_of_day.yesterday, 'booked,fulfilled,arrived')
        sort_recent_appointments(appointments[:data])
      end

      def sort_recent_appointments(appointments)
        filtered_appts = appointments.reject { |appt| appt&.start.nil? }
        removed_appts = appointments - filtered_appts
        if removed_appts.length.positive?
          removed_appts.each do |rem_appt|
            Rails.logger.info("VAOS appointment sorting filtered out id #{rem_appt.id} due to missing start time.")
          end
        end
        filtered_appts.sort_by { |appointment| DateTime.parse(appointment.start) }.reverse
      end

      # Returns the facility timezone id (eg. 'America/New_York') associated with facility id (location_id)
      def get_facility_timezone(facility_location_id)
        facility_info = mobile_facility_service.get_facility(facility_location_id) unless facility_location_id.nil?
        return nil if facility_info.nil?

        facility_info[:timezone]&.[](:time_zone_id)
      end

      # Returns the facility timezone id (eg. 'America/New_York') associated with facility id (location_id)
      def get_facility_timezone_memoized(facility_location_id)
        facility_info = mobile_facility_service.get_facility(facility_location_id) unless facility_location_id.nil?
        return nil if facility_info.nil?

        facility_info[:timezone]&.[](:time_zone_id)
      end

      def merge_appointments(eps_appointments, appointments)
        normalized_new = eps_appointments.map(&:serializable_hash)
        existing_referral_ids = appointments.to_set { |a| a.dig(:referral, :referral_number) }
        date_and_time_for_referral_list = appointments.pluck(:start)
        merged_data = appointments + normalized_new.reject do |a|
          existing_referral_ids.include?(a.dig(:referral,
                                               :referral_number)) && date_and_time_for_referral_list.include?(a[:start])
        end
        merged_data.sort_by { |appt| appt[:start] || '' }
      end

      memoize :get_facility_timezone_memoized

      private

      # rubocop:disable Metrics/MethodLength
      def parse_possible_token_related_errors(e, method_name)
        prefix = "VAOS::V2::AppointmentService##{method_name}"
        sanitized_icn = VAOS::Anonymizers.anonymize_icns(user.icn)
        sanitized_message = VAOS::Anonymizers.anonymize_icns(e.message)
        case e
        when Common::Client::Errors::ParsingError
          Rails.logger.warn("#{prefix} token failed, parsing error", icn: sanitized_icn, context: sanitized_message)
          sanitized_message
        when Common::Exceptions::GatewayTimeout
          Rails.logger.warn("#{prefix} token failed, gateway timeout", icn: sanitized_icn)
          sanitized_message
        when MAP::SecurityToken::Errors::ApplicationMismatchError
          Rails.logger.warn("#{prefix} application mismatch", icn: sanitized_icn, context: sanitized_message)
          sanitized_message
        when MAP::SecurityToken::Errors::MissingICNError
          Rails.logger.warn("#{prefix} missing ICN")
          sanitized_message
        when Common::Client::Errors::ClientError
          status = e.status
          context = e.body
          message = "#{prefix} token failed, status: #{status}"
          Rails.logger.warn(message.to_s, status:, icn: sanitized_icn, context:)
          { message:, status:, icn: sanitized_icn, context: }
        end
      end

      # rubocop:enable Metrics/MethodLength

      # Modifies the appointment, extracting individual fields from the appointment. This currently includes:
      # 1. Reason code fields
      # 2. Preferred dates for requests (if not available from reason code fields)
      #
      # @param appointment [Hash] the appointment to modify
      def extract_appointment_fields(appointment)
        reason_code_service.extract_reason_code_fields(appointment)

        # Fallback to extracting preferred dates from a request's requested periods
        extract_request_preferred_dates(appointment)
      end

      # Extract preferred date from the requested periods if necessary.
      #
      # @param @param appointment [Hash] the appointment to modify
      def extract_request_preferred_dates(appointment)
        # Do not overwrite preferred dates if they are already present
        requested_periods = appointment[:requested_periods]
        if requested_periods.present? && appointment[:preferred_dates].blank?
          dates = []

          requested_periods.each do |period|
            unless period&.[](:start).nil?
              datetime = DateTime.parse(period[:start])
              if datetime.strftime('%p') == 'AM'
                dates.push(datetime.strftime(OUTPUT_FORMAT_AM))
              else
                dates.push(datetime.strftime(OUTPUT_FORMAT_PM))
              end
            end
          end

          appointment[:preferred_dates] = dates unless dates.nil?
        end
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

      def fetch_clinic_appointments(start_time, end_time, statuses)
        get_appointments(start_time, end_time, statuses)[:data].select { |appt| appt.kind == 'clinic' }
      end

      def prepare_appointment(appointment, include = {})
        # for CnP, covid, CC and telehealth appointments set cancellable to false per GH#57824, GH#58690, ZH#326
        set_cancellable_false(appointment) if cannot_be_cancelled?(appointment)

        # remove service type(s) for non-medical non-CnP appointments per GH#56197
        unless medical?(appointment) || cnp?(appointment) || no_service_cat?(appointment)
          remove_service_type(appointment)
        end

        # set requestedPeriods to nil if the appointment is a booked cerner appointment per GH#62912
        appointment[:requested_periods] = nil if booked?(appointment) && VAOS::AppointmentsHelper.cerner?(appointment)

        convert_appointment_time(appointment)

        appointment[:station], appointment[:ien] = extract_station_and_ien(appointment)

        appointment[:minutes_duration] ||= 60 if appointment[:appointment_type] == 'COMMUNITY_CARE'

        extract_appointment_fields(appointment)

        fetch_avs_and_update_appt_body(appointment) if avs_applicable?(appointment, include[:avs])

        if cc?(appointment) && %w[proposed cancelled].include?(appointment[:status])
          find_and_merge_provider_name(appointment)
        end

        merge_clinic(appointment) if include[:clinics]

        merge_facility(appointment) if include[:facilities]

        set_type(appointment)

        set_modality(appointment)

        set_telehealth_visibility(appointment) if telehealth?(appointment)

        set_derived_appointment_date_fields(appointment)
      end

      def find_and_merge_provider_name(appointment)
        practitioners_list = appointment[:practitioners]
        names = appointment_provider_name_service.form_names_from_appointment_practitioners_list(practitioners_list)

        appointment[:preferred_provider_name] = names
      end

      def merge_clinic(appt)
        return if appt[:clinic].nil? || appt[:location_id].nil?

        clinic = mobile_facility_service.get_clinic(appt[:location_id], appt[:clinic])
        if clinic&.[](:service_name)
          # In VAOS Service there is no dedicated clinic friendlyName field.
          # If the clinic is configured with a patient-friendly name then that will be the value
          # in the clinic service name; otherwise it will be the internal clinic name.
          appt[:service_name] = clinic[:service_name]
        end

        appt[:physical_location] = clinic[:physical_location] if clinic&.[](:physical_location)
      end

      def merge_facility(appt)
        appt[:location] = mobile_facility_service.get_facility(appt[:location_id]) unless appt[:location_id].nil?
        VAOS::AppointmentsHelper.log_appt_id_location_name(appt)
      end

      def appointment_provider_name_service
        @appointment_provider_name_service ||= AppointmentProviderName.new(user)
      end

      def most_recent_appointment(appointments)
        appointments.max_by { |appointment| DateTime.parse(appointment.start) }
      end

      def mobile_facility_service
        @mobile_facility_service ||= VAOS::V2::MobileFacilityService.new(user)
      end

      def avs_service
        @avs_service ||= Avs::V0::AvsService.new
      end

      def reason_code_service
        @reason_code_service ||= VAOS::V2::AppointmentsReasonCodeService.new
      end

      def log_cnp_appt_count(cnp_count)
        Rails.logger.info('Compensation and Pension count on an appointment list retrieval',
                          { CompPenCount: cnp_count }.to_json)
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
        return nil if appt[:station].nil? || appt[:ien].nil?

        avs_resp = avs_service.get_avs_by_appointment(appt[:station], appt[:ien])

        return nil if avs_resp.body.empty? || !(avs_resp.body.is_a?(Array) && avs_resp.body.first.is_a?(Hash))

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
        if appt[:id].nil?
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

      # Determines if the appointment cannot be cancelled.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment cannot be cancelled
      def cannot_be_cancelled?(appointment)
        cnp?(appointment) || covid?(appointment) || appointment[:start]&.to_datetime&.past? ||
          (cc?(appointment) && booked?(appointment)) || telehealth?(appointment)
      end

      # Checks if appointment is eligible for receiving an AVS link, i.e.
      # the appointment is booked and in the past
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is eligible, false otherwise
      #
      def avs_applicable?(appt, avs)
        return false if appt.nil? || appt[:status].nil? || appt[:start].nil? || avs.nil?

        appt[:status] == 'booked' && appt[:start].to_datetime.past? && avs
      end

      # Filters out non-ASCII characters from the reason code text field in the request object body.
      #
      # @param request_object_body [Hash, ActionController::Parameters] The request object body containing
      # the reason code text field.
      #
      # @return [String, nil] The filtered reason text, or nil if the reason code text is not present or nil.
      #
      def filter_reason_code_text(request_object_body)
        text = request_object_body&.dig(:reason_code, :text)
        VAOS::Strings.filter_ascii_characters(text) if text.present?
      end

      # Determines if the appointment is a Cerner (Oracle Health) appointment.
      # This is determined by the presence of a 'CERN' prefix in the appointment's id.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is a Cerner appointment, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def cerner?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:id].start_with?('CERN')
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

      # Determines if the appointment is for community care.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for community care, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def cc?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:kind] == 'cc'
      end

      # Determines if the appointment is for telehealth.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is for telehealth, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def telehealth?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt[:kind] == 'telehealth'
      end

      # Determines if the appointment is a request type.
      # Note that this should only be called after appt[:type] has been set by set_type.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment is a request, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def request?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        %w[REQUEST COMMUNITY_CARE_REQUEST].include?(appt[:type])
      end

      # Determines if the appointment occurs in the past.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment occurs in the past, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def past?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt_start = appt[:start] || appt.dig(:requested_periods, 0, :start)

        unless appt_start.nil?
          appt[:past] = if appt[:kind] == 'telehealth'
                          (appt_start.to_datetime + 240.minutes) < Time.now.utc
                        else
                          (appt_start.to_datetime + 60.minutes) < Time.now.utc
                        end
        end
      end

      # Determines if the appointment occurs in the future.
      # Note that this should only be called after appt[:type] has been set by set_type.
      #
      # @param appt [Hash] the appointment to check
      # @return [Boolean] true if the appointment occurs in the future, false otherwise
      #
      # @raise [ArgumentError] if the appointment is nil
      #
      def future?(appt)
        raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

        appt_start = appt[:start] || appt.dig(:requested_periods, 0, :start)

        appt[:future] = !appt_start.nil? &&
                        !request?(appt) &&
                        !past?(appt)
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

          if appt[:location_id] == MANILA_PHILIPPINES_FACILITY_ID
            log_timezone_info(appt[:location_id], facility_timezone, appt[:start], appt[:local_start_time])
          end

        elsif !appt.dig(:requested_periods, 0, :start).nil?
          appt[:requested_periods].each do |period|
            facility_timezone = get_facility_timezone_memoized(appt[:location_id])
            period[:local_start_time] = convert_utc_to_local_time(period[:start], facility_timezone)

            if appt[:location_id] == MANILA_PHILIPPINES_FACILITY_ID
              log_timezone_info(appt[:location_id], facility_timezone, period[:start], period[:local_start_time])
            end
          end
        end
        appt
      end

      def log_timezone_info(appt_location_id, facility_timezone, appt_start_time_utc, appt_start_time_local)
        Rails.logger.info(
          "Timezone info for Manila Philippines location_id #{appt_location_id}",
          {
            location_id: appt_location_id,
            facility_timezone:,
            appt_start_time_utc:,
            appt_start_time_local:
          }.to_json
        )
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

      def log_direct_schedule_submission_errors(e)
        error_entry = { DIRECT_SCHEDULE_ERROR_KEY => ds_error_details(e) }
        Rails.logger.warn('Direct schedule submission error', error_entry.to_json)
      end

      def set_type(appointment)
        type = if cerner?(appointment)
                 cerner_type(appointment)
               else
                 non_cerner_type(appointment)
               end

        appointment[:type] = type
      end

      # Determines the type of appointment for Cerner appointments.
      # @param appointment [Hash] the appointment to determine the type for
      #
      # @return [String] the type of appointment
      #
      def cerner_type(appointment)
        if appointment[:end].present?
          appointment[:kind] == 'cc' ? APPOINTMENT_TYPES[:cc_appointment] : APPOINTMENT_TYPES[:va]
        else
          appointment[:kind] == 'cc' ? APPOINTMENT_TYPES[:cc_request] : APPOINTMENT_TYPES[:request]
        end
      end

      # Determines the type of appointment for non-Cerner appointments.
      # @param appointment [Hash] the appointment to determine the type for
      #
      # @return [String] the type of appointment
      #
      def non_cerner_type(appointment)
        if appointment[:kind] == 'cc'
          if appointment[:requested_periods].present?
            APPOINTMENT_TYPES[:cc_request]
          else
            APPOINTMENT_TYPES[:cc_appointment]
          end
        elsif appointment[:requested_periods].present?
          APPOINTMENT_TYPES[:request]
        else
          APPOINTMENT_TYPES[:va]
        end
      end

      # Modifies the appointment, setting the cancellable flag to false
      #
      # @param appointment [Hash] the appointment to modify
      def set_cancellable_false(appointment)
        appointment[:cancellable] = false
      end

      def set_telehealth_visibility(appointment)
        if appointment[:telehealth] && appointment[:modality] == 'vaVideoCareAtHome' && appointment[:start]
          # if current time is between 30 minutes prior to appointment.start and 4 hours after appointment.start, set
          # telehealth_visible to true
          appointment[:telehealth][:displayLink] = (appointment[:start].to_datetime - 30.minutes) <= Time.now.utc &&
                                                   (appointment[:start].to_datetime + 4.hours) >= Time.now.utc
        end
      end

      def set_modality(appointment)
        raise ArgumentError, 'Appointment cannot be nil' if appointment.nil?

        modality = nil
        if appointment[:service_type] == 'covid'
          modality = 'vaInPersonVaccine'
        elsif appointment.dig(:service_category, 0, :text) == 'COMPENSATION & PENSION'
          modality = 'claimExamAppointment'
        elsif appointment[:kind] == 'clinic'
          modality = 'vaInPerson'
        elsif appointment[:kind] == 'telehealth'
          modality = telehealth_modality(appointment)
        elsif appointment[:kind] == 'phone'
          modality = 'vaPhone'
        elsif appointment[:kind] == 'cc'
          modality = 'communityCare'
        end

        log_modality_failure(appointment) if modality.nil?
        appointment[:modality] = modality
      end

      def set_derived_appointment_date_fields(appointment)
        appointment[:pending] = request?(appointment)
        appointment[:past] = past?(appointment)
        appointment[:future] = future?(appointment)
      end

      def log_modality_failure(appointment)
        context = {
          service_type: appointment[:service_type],
          service_category_text: appointment.dig(:service_category, 0, :text),
          kind: appointment[:kind],
          atlas: appointment.dig(:telehealth, :atlas),
          vvs_kind: appointment.dig(:telehealth, :vvs_kind)
        }.to_json
        Rails.logger.warn("VAOS appointment id #{appointment[:id]} modality cannot be determined", context)
      end

      def telehealth_modality(appointment)
        vvs_kind = appointment.dig(:telehealth, :vvs_kind)
        if !appointment.dig(:telehealth, :atlas).nil?
          'vaVideoCareAtAnAtlasLocation'
        elsif %w[CLINIC_BASED STORE_FORWARD].include?(vvs_kind)
          'vaVideoCareAtAVaLocation'
        elsif %w[MOBILE_ANY ADHOC].include?(vvs_kind)
          'vaVideoCareAtHome'
        elsif vvs_kind.nil?
          'vaInPerson'
        end
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

      def partial_errors(response, method_name)
        return { failures: [] } if response.body[:failures].blank?

        log_partial_errors(response, method_name)

        {
          failures: response.body[:failures]
        }
      end

      # Logs partial errors from a response.
      #
      # @param response [Faraday::Env] The response object containing the status and body.
      #
      # @return [nil]
      #
      def log_partial_errors(response, method_name)
        return unless response.status == 200

        failures_dup = response.body[:failures].deep_dup
        failures_dup.each do |failure|
          detail = failure[:detail]
          failure[:detail] = VAOS::Anonymizers.anonymize_icns(detail) if detail.present?
        end

        log_message_to_sentry(
          "VAOS::V2::AppointmentService##{method_name} has response errors.",
          :info,
          failures: failures_dup.to_json
        )
      end

      def appointments_base_path_vaos
        "/#{base_vaos_route}/patients/#{user.icn}/appointments"
      end

      def appointments_base_path_vpg
        "/vpg/v1/patients/#{user.icn}/appointments"
      end

      def avs_path(sid)
        "/my-health/medical-records/summaries-and-notes/visit-summary/#{sid}"
      end

      def get_appointment_base_path(appointment_id)
        if Flipper.enabled?(APPOINTMENTS_USE_VPG, user)
          "/vpg/v1/patients/#{user.icn}/appointments/#{appointment_id}"
        else
          "/#{base_vaos_route}/patients/#{user.icn}/appointments/#{appointment_id}"
        end
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
        body = [VAOS::V2::UpdateAppointmentForm.new(status:).json_patch_op]
        perform(:patch, url_path, body, headers)
      end

      def update_appointment_vaos(appt_id, status)
        url_path = "/#{base_vaos_route}/patients/#{user.icn}/appointments/#{appt_id}"
        params = VAOS::V2::UpdateAppointmentForm.new(status:).params
        perform(:put, url_path, params, headers)
      end

      def validate_response_schema(response, contract_name)
        return unless response.success? && response.body[:data].present?

        SchemaContract::ValidationInitiator.call(user:, response:, contract_name:)
      end

      def merge_all_travel_claims(start_date, end_date, appointments)
        service = TravelPay::ClaimAssociationService.new(user)
        service.associate_appointments_to_claims(
          {
            'start_date' => start_date,
            'end_date' => end_date,
            'appointments' => appointments
          }
        )
      end

      def merge_one_travel_claim(appointment)
        service = TravelPay::ClaimAssociationService.new(user)
        service.associate_single_appointment_to_claim({ 'appointment' => appointment })
      end

      def eps_appointments_service
        @eps_appointments_service ||=
          Eps::AppointmentService.new(user)
      end

      def eps_appointments
        @eps_appointments ||= begin
          appointments = eps_appointments_service.get_appointments[:data]
          appointments = [] if appointments.blank? || appointments.all?(&:empty?)
          appointments.reject! { |appt| appt.dig(:appointment_details, :start).nil? }
          appointments.map { |appt| VAOS::V2::EpsAppointment.new(appt) }
        end
      end

      def eps_serializer
        @eps_serializer ||= VAOS::V2::EpsAppointment.new
      end

      ##
      # Retrieves all appointments over a 200-year window, a temporary range to be replaced with passed
      # in date from referral data.
      #
      # Uses a fixed date range to fetch all appointments.
      # If the response contains failures (in :meta), it returns the raw response.
      # Otherwise, it returns a hash with appointment data and any partial errors.
      #
      # @param pagination_params [Hash] pagination options (e.g. page and per_page).
      #
      # @return [Hash] A hash consistent with the structure returned by #get_appointments:
      #   - :data [Array] the appointment data
      #   - :meta [Hash] any partial error details
      #
      # TODO: accept date from cached referral data to use for range
      def get_all_appointments(pagination_params)
        start_date = (Time.zone.today - 100.years).in_time_zone
        end_date   = (Time.zone.today + 100.years).in_time_zone

        response = send_appointments_request(start_date, end_date, __method__, pagination_params)

        return response if response.dig(:meta, :failures)

        {
          data: response.body[:data],
          meta: partial_errors(response, __method__)
        }
      end

      ##
      # Sends an appointment request to the upstream API.
      #
      # Builds the request parameters from the given date range, pagination options, and status filters,
      # sends the GET request to the appropriate endpoint (VAOS or VPG), and validates the response schema.
      # In case of an error, it returns a structured error hash.
      #
      # @param start_date [Time, DateTime, String] the start date for the appointment query.
      # @param end_date [Time, DateTime, String] the end date for the appointment query.
      # @param caller_name [Symbol, String] the name of the calling method (used for logging errors).
      # @param pagination_params [Hash] (optional) pagination options (e.g. page and per_page).
      # @param statuses [Array, nil] (optional) a list of appointment statuses to filter by.
      #
      # @return [Object, Hash] the API response object if successful, or a hash with error details
      #   in the format { data: {}, meta: { failures: ... } } if an error occurs.
      def send_appointments_request(start_date, end_date, caller_name, pagination_params = {}, statuses = nil)
        req_params = build_appointment_request_params(start_date, end_date, pagination_params, statuses)

        response   = perform_appointment_request(req_params)
        validate_response_schema(response, 'appointments_index')
        response
      rescue Common::Client::Errors::ParsingError, Common::Client::Errors::ClientError,
             Common::Exceptions::GatewayTimeout, MAP::SecurityToken::Errors::ApplicationMismatchError,
             MAP::SecurityToken::Errors::MissingICNError => e
        handle_appointment_request_error(e, caller_name, pagination_params)
      end

      ##
      # Builds a hash of request parameters for the appointments API.
      #
      # Combines the date range, pagination options, and status filters into a single hash
      # and removes any nil values.
      #
      # @param start_date [Time, DateTime, String] the start of the date range.
      # @param end_date [Time, DateTime, String] the end of the date range.
      # @param pagination_params [Hash] pagination options (e.g. page and per_page).
      # @param statuses [Array, nil] a list of appointment statuses to filter by.
      #
      # @return [Hash] the merged request parameters with nil values removed.
      def build_appointment_request_params(start_date, end_date, pagination_params, statuses)
        date_params(start_date, end_date)
          .merge(page_params(pagination_params))
          .merge(status_params(statuses))
          .compact
      end

      ##
      # Performs a GET request to the appointments API.
      #
      # Chooses the appropriate endpoint (VAOS or VPG) based on feature flags,
      # and sends a GET request with the given request parameters and headers,
      # all within a monitoring block.
      #
      # @param req_params [Hash] The request parameters to be sent with the GET request.
      # @return [Faraday::Response] The API response.
      def perform_appointment_request(req_params)
        with_monitoring do
          if Flipper.enabled?(APPOINTMENTS_USE_VPG, user)
            perform(:get, appointments_base_path_vpg, req_params, headers)
          else
            perform(:get, appointments_base_path_vaos, req_params, headers)
          end
        end
      end

      ##
      # Handles errors from the appointment request.
      #
      # Constructs and returns a hash with an empty data payload and metadata
      # containing parsed failure messages from the given exception.
      #
      # @param exception [Exception] the exception raised during the request.
      # @param caller_name [Symbol, String] the name of the calling method for logging.
      # @param pagination_params [Hash] the pagination parameters used in the request.
      #
      # @return [Hash] a hash with keys:
      #   - :data, an empty hash,
      #   - :meta, a merge of pagination info and a :failures array with error messages.
      def handle_appointment_request_error(exception, caller_name, pagination_params)
        {
          data: {},
          meta: pagination(pagination_params).merge({
                                                      failures: parse_possible_token_related_errors(exception,
                                                                                                    caller_name)
                                                    })
        }
      end
    end
  end
end
