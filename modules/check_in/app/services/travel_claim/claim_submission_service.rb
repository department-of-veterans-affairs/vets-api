# frozen_string_literal: true

module TravelClaim
  class ClaimSubmissionService
    attr_reader :check_in, :appointment_date, :facility_type, :uuid

    def initialize(check_in:, appointment_date:, facility_type:, uuid:)
      @check_in = check_in
      @appointment_date = appointment_date
      @facility_type = facility_type
      @uuid = uuid
    end

    def submit_claim
      validate_parameters
      result = process_claim_submission
      send_notification_if_enabled if result['success']
      result
    rescue Common::Exceptions::BackendServiceException => e
      send_error_notification_if_enabled(e)
      raise
    rescue => e
      log_message(:error, 'Unexpected error', error_class: e.class.name, error: e.message)
      send_error_notification_if_enabled(e)
      raise
    end

    private

    def process_claim_submission
      log_message(:info, 'Travel claim transaction START')
      icn, station = fetch_required_identifiers
      enforce_idempotency!
      client = build_client(icn:, station:)
      appt_id = ensure_appointment(client)
      claim_id = ensure_claim(client, appt_id)
      add_mileage(client, claim_id)
      submit_claim_and_capture_last_four(client, claim_id)
      { 'success' => true, 'claimId' => claim_id }
    end

    def fetch_required_identifiers
      icn = redis.icn(uuid: check_in.uuid)
      station = redis.station_number(uuid:)
      raise_backend_service_exception('ICN is required', 400, 'VA902') if icn.blank?
      raise_backend_service_exception('Station number is required', 400, 'VA903') if station.blank?
      [icn, station]
    end

    def enforce_idempotency!
      key = "travel_claim:submit:#{uuid}:#{Date.parse(appointment_date).strftime('%F')}"
      locked = Rails.cache.fetch(key, expires_in: 120) { 'locked' }
      raise_backend_service_exception('Duplicate in-flight request', 409, 'VA906') unless locked == 'locked'
    end

    def build_client(icn:, station:)
      TravelClaim::TravelPayClient.new(
        uuid:, check_in_uuid: check_in.uuid, appointment_date_time: appointment_date,
        icn:, station_number: station
      )
    end

    def ensure_appointment(client)
      id = client.find_or_add_appointment!
      raise_backend_service_exception('Appointment could not be found or created', 502) if id.blank?
      id
    end

    def ensure_claim(client, appointment_id)
      id = client.create_claim!(appointment_id:)
      raise_backend_service_exception('Failed to create claim', 502) if id.blank?
      id
    end

    def add_mileage(client, claim_id)
      client.add_mileage_expense!(claim_id:, date_incurred: appointment_date)
    end

    def submit_claim_and_capture_last_four(client, claim_id)
      body = client.submit_claim!(claim_id:)
      @claim_number_last_four = extract_claim_number_last_four(body)
    end

    def validate_parameters
      raise_backend_service_exception('CheckIn object is required', 400, 'VA901') if check_in.nil?
      raise_backend_service_exception('Appointment date is required', 400, 'VA902') if appointment_date.blank?
      raise_backend_service_exception('Facility type is required', 400, 'VA903') if facility_type.blank?
      raise_backend_service_exception('Uuid is required', 400, 'VA904') if uuid.blank?
      validate_appointment_date_format
    end

    def validate_appointment_date_format
      DateTime.iso8601(appointment_date)
    rescue ArgumentError
      raise_backend_service_exception(
        'Appointment date must be a valid ISO 8601 date-time (e.g., 2025-09-16T10:00:00Z)', 400, 'VA905'
      )
    end

    def extract_claim_number_last_four(body)
      payload = body.is_a?(String) ? JSON.parse(body) : body
      payload.dig('data', 'claimId')&.last(4) || 'unknown'
    rescue => e
      log_message(:error, 'Failed to extract claim number', error: e.message)
      'unknown'
    end

    def redis
      @redis ||= TravelClaim::RedisClient.build
    end

    def log_message(level, message, meta = {})
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      Rails.logger.public_send(level, {
        message: "CIE Travel Claim Submission: #{message}",
        facility_type:, check_in_uuid: uuid
      }.merge(meta))
    end

    def raise_backend_service_exception(detail, status = 502, code = 'VA900')
      raise Common::Exceptions::BackendServiceException.new(code, { detail: }, status)
    end

    def notification_enabled?
      Flipper.enabled?(:check_in_experience_travel_reimbursement)
    end

    def success_template_id
      facility_type&.downcase == 'oh' ? CheckIn::Constants::OH_SUCCESS_TEMPLATE_ID : CheckIn::Constants::CIE_SUCCESS_TEMPLATE_ID
    end

    def error_template_id
      facility_type&.downcase == 'oh' ? CheckIn::Constants::OH_ERROR_TEMPLATE_ID : CheckIn::Constants::CIE_ERROR_TEMPLATE_ID
    end

    def determine_error_template_id(error)
      dup = error.is_a?(Common::Exceptions::BackendServiceException) &&
            error.response_values[:detail]&.include?('already been created')
      if dup
        return (facility_type&.downcase == 'oh' ? CheckIn::Constants::OH_DUPLICATE_TEMPLATE_ID : CheckIn::Constants::CIE_DUPLICATE_TEMPLATE_ID)
      end

      error_template_id
    end

    def format_appointment_date
      Date.parse(appointment_date).strftime('%Y-%m-%d')
    rescue
      appointment_date
    end

    def send_notification_if_enabled
      return unless notification_enabled?

      CheckIn::TravelClaimNotificationJob.perform_async(uuid, format_appointment_date, success_template_id,
                                                        @claim_number_last_four)
    end

    def send_error_notification_if_enabled(error)
      return unless notification_enabled?

      tpl = determine_error_template_id(error)
      last4 = @claim_number_last_four || 'unknown'
      CheckIn::TravelClaimNotificationJob.perform_async(uuid, format_appointment_date, tpl, last4)
    end
  end
end
