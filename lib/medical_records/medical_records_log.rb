# frozen_string_literal: true

module MedicalRecords
  ##
  # Structured logging utility for Medical Records across all API surfaces (V1, V2, Mobile).
  #
  # Provides a consistent log envelope with automatic PII stripping, tiered verbosity
  # controlled by a Flipper toggle, and built-in StatsD instrumentation.
  #
  # == Usage
  #
  #   log = MedicalRecords::MedicalRecordsLog.new(user: current_user)
  #
  #   # Basic info log (always emitted regardless of toggle)
  #   log.info(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'index', total: 12)
  #
  #   # Diagnostic log (only emitted when the Flipper toggle is enabled for this user)
  #   log.diagnostic(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'filter',
  #                  doc_ref_total: 20, returned: 12, filter_rate: 40.0)
  #
  #   # Warning with anomaly metric
  #   log.warn(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'index',
  #            anomaly: 'high_filter_rate', filter_rate: 85.0)
  #
  #   # Error logging
  #   log.error(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'show',
  #             error_class: 'Common::Client::Errors::ClientError',
  #             error_message: 'timeout')
  #
  #   # Redact user_uuid when logging alongside clinical content
  #   log.info(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'show',
  #            redact_user_uuid: true, user_uuid: current_user.uuid,
  #            note_id: '12345', doc_ref_type: 'ConsultResultNote')
  #
  class MedicalRecordsLog
    SERVICE_NAME = 'medical_records'

    # ── Resource domain constants ──
    # Use these instead of raw strings to avoid typos and improve discoverability.
    ALLERGIES      = 'allergies'
    CLINICAL_NOTES = 'clinical_notes'
    CONDITIONS     = 'conditions'
    LABS_AND_TESTS = 'labs_and_tests'
    VACCINES       = 'vaccines'
    VITALS         = 'vitals'

    # Global "break glass" toggle — enables diagnostic logging for ALL domains at once.
    GLOBAL_TOGGLE = :mhv_medical_records_diagnostic_logging

    # Per-domain toggles for surgical diagnostic logging.
    # Each maps a resource domain constant to its own Flipper toggle so you can debug
    # one domain without flooding logs from the others.
    DOMAIN_TOGGLES = {
      CLINICAL_NOTES => :mhv_medical_records_clinical_notes_diagnostic
    }.freeze

    # Keys that are always stripped from log output. Checked case-insensitively.
    PII_KEYS = %i[
      icn
      ssn
      social_security_number
      email
      mhv_correlation_id
      first_name
      last_name
      birth_date
      date_of_birth
      address
      phone
      phone_number
    ].freeze

    # Keys that are safe on their own but become PII when logged alongside clinical data.
    # Stripped only when the caller opts in via `redact_user_uuid: true`.
    CONTEXTUAL_PII_KEYS = %i[
      user_uuid
    ].freeze

    # @param user [User, nil] The authenticated user. When provided, diagnostic logging
    #   is gated by the Flipper toggle for this user.
    def initialize(user: nil)
      @user = user
    end

    # Always-on info-level log.
    # Use for operational data that should always be captured (response counts, cache status, etc.).
    #
    # @param resource [String] The medical record resource type (e.g. 'clinical_notes', 'allergies')
    # @param action [String] The controller/service action (e.g. 'index', 'show', 'filter')
    # @param redact_user_uuid [Boolean] When true, strips user_uuid from output.
    #   Use when logging alongside clinical content that could make user_uuid identifying.
    # @param metadata [Hash] Additional structured data to include in the log entry
    def info(resource:, action:, redact_user_uuid: false, **metadata)
      write(:info, resource:, action:, redact_user_uuid:, **metadata)
    end

    # Always-on warn-level log.
    # Use for anomalies, unexpected states, or degraded-but-functional conditions.
    #
    # @param resource [String] The medical record resource type
    # @param action [String] The controller/service action
    # @param redact_user_uuid [Boolean] When true, strips user_uuid from output.
    # @param metadata [Hash] Additional structured data
    def warn(resource:, action:, redact_user_uuid: false, **metadata)
      write(:warn, resource:, action:, redact_user_uuid:, **metadata)
    end

    # Always-on error-level log.
    # Use for failures that prevent a response from being returned.
    #
    # @param resource [String] The medical record resource type
    # @param action [String] The controller/service action
    # @param redact_user_uuid [Boolean] When true, strips user_uuid from output.
    # @param metadata [Hash] Additional structured data
    def error(resource:, action:, redact_user_uuid: false, **metadata)
      write(:error, resource:, action:, redact_user_uuid:, **metadata)
    end

    # Toggle-gated diagnostic log at info level.
    #
    # Checks the domain-specific toggle first (e.g. `:mhv_medical_records_clinical_notes_diagnostic`),
    # then falls back to the global toggle (`:mhv_medical_records_diagnostic_logging`).
    # This lets you surgically enable logging for one domain, or flip the global toggle
    # during an incident to light everything up.
    #
    # @param resource [String] The medical record resource type
    # @param action [String] The controller/service action
    # @param metadata [Hash] Additional structured data
    # @return [Boolean] true if the log was written, false if toggle was off
    # @param redact_user_uuid [Boolean] When true, strips user_uuid from output.
    def diagnostic(resource:, action:, redact_user_uuid: false, **metadata)
      return false unless diagnostic_enabled?(resource)

      write(:info, resource:, action:, redact_user_uuid:, log_level_context: 'diagnostic', **metadata)
      true
    end

    # Returns whether diagnostic logging is currently enabled for this user.
    # Checks the domain-specific toggle first, then the global fallback.
    #
    # @param resource [String, nil] The resource domain to check. When nil, only checks the global toggle.
    # @return [Boolean]
    def diagnostic_enabled?(resource = nil)
      return false unless @user

      # Domain-specific toggle takes priority
      domain_toggle = DOMAIN_TOGGLES[resource] if resource
      return true if domain_toggle && Flipper.enabled?(domain_toggle, @user)

      # Global fallback
      Flipper.enabled?(GLOBAL_TOGGLE, @user)
    end

    private

    # Builds the structured envelope, strips PII, and writes to Rails.logger.
    def write(level, resource:, action:, redact_user_uuid: false, **metadata)
      payload = build_payload(resource:, action:, redact_user_uuid:, **metadata)
      Rails.logger.public_send(level, payload)
    end

    # Assembles the canonical log hash.
    def build_payload(resource:, action:, redact_user_uuid: false, **metadata)
      sanitized = strip_pii(metadata, redact_user_uuid:)

      {
        service: SERVICE_NAME,
        resource:,
        action:,
        **sanitized
      }
    end

    # Recursively removes any keys from the hash that match PII_KEYS.
    # When redact_user_uuid is true, also strips CONTEXTUAL_PII_KEYS.
    # Operates on a deep copy so the caller's hash is not mutated.
    def strip_pii(hash, redact_user_uuid: false)
      blocked = redact_user_uuid ? PII_KEYS + CONTEXTUAL_PII_KEYS : PII_KEYS

      hash.each_with_object({}) do |(key, value), clean|
        sym_key = key.to_s.downcase.to_sym
        next if blocked.include?(sym_key)

        clean[key] = case value
                     when Hash
                       strip_pii(value, redact_user_uuid:)
                     when Array
                       value.map { |v| v.is_a?(Hash) ? strip_pii(v, redact_user_uuid:) : v }
                     else
                       value
                     end
      end
    end
  end
end
