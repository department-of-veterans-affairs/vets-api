# frozen_string_literal: true

module MedicalRecords
  ##
  # Structured logging utility for Medical Records across all API surfaces (V1, V2, Mobile).
  #
  # == Design Philosophy
  #
  # Medical Records logging has two competing needs: *visibility* during incidents and
  # *quiet* during normal operation. This class resolves that tension with a two-tier
  # model:
  #
  # * **Always-on methods** (+info+, +warn+, +error+) — for data you always want:
  #   response counts, cache status, errors.
  # * **Toggle-gated method** (+diagnostic+) — for verbose instrumentation you only
  #   enable when debugging: filter rates, LOINC distributions, source breakdowns.
  #
  # Every log entry passes through +strip_pii+ before reaching +Rails.logger+, so
  # even if a caller accidentally includes an +icn+ or +ssn+ key, it is silently
  # removed. This is a safety net, not an excuse to pass PII intentionally.
  #
  # == Toggle Pattern
  #
  # Diagnostic logging uses a *domain + global fallback* pattern:
  #
  # 1. Check the per-domain toggle for the resource (e.g.
  #    +:mhv_medical_records_clinical_notes_diagnostic+).
  # 2. If not enabled, fall back to the global toggle
  #    (+:mhv_medical_records_diagnostic_logging+).
  # 3. Enabling *either* activates diagnostic logging for that user.
  #
  # This lets you surgically debug one domain in production, or flip the global
  # toggle during an incident to light up diagnostics across all domains at once.
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
  # == Adding a New Domain
  #
  # Follow these steps when you want structured logging for a new domain
  # (e.g. allergies, vitals). Clinical Notes is the reference implementation.
  #
  # 1. *Add a domain constant* — A constant already exists (e.g. +ALLERGIES+).
  #    Use it in all +resource:+ arguments to avoid string typos.
  #
  # 2. *Register a domain toggle* — Add an entry to +DOMAIN_TOGGLES+:
  #
  #      DOMAIN_TOGGLES = {
  #        CLINICAL_NOTES => :mhv_medical_records_clinical_notes_diagnostic,
  #        ALLERGIES      => :mhv_medical_records_allergies_diagnostic,   # new
  #      }.freeze
  #
  # 3. *Register the toggle in features.yml* — Add a corresponding entry under
  #    +features:+ (keep alphabetical order):
  #
  #      mhv_medical_records_allergies_diagnostic:
  #        actor_type: user
  #        description: Enables diagnostic logging for allergies only.
  #        enable_in_development: false
  #
  # 4. *Create a logging concern* (recommended) — Extract logging methods into
  #    a concern like +ClinicalNotesLogging+ to keep service classes short.
  #    The concern should:
  #    - Memoize an +MedicalRecordsLog+ instance via +mr_log+.
  #    - Expose domain-specific helper methods (e.g. +log_allergy_metrics+).
  #    - Use +mr_log.diagnostic+ for verbose data and +mr_log.info/warn/error+
  #      for always-on operational data.
  #    - Guard expensive computation with an early +return unless+ when the
  #      toggle is off (see +ClinicalNotesLogging#log_loinc_code_distribution+).
  #
  #    See +lib/unified_health_data/concerns/clinical_notes_logging.rb+ for
  #    the reference implementation.
  #
  # 5. *Include the concern* in your service class:
  #
  #      class UnifiedHealthData::Service
  #        include UnifiedHealthData::Concerns::AllergiesLogging
  #      end
  #
  # 6. *Write specs* — Stub Flipper toggles (never use +Flipper.enable+) and
  #    assert on +Rails.logger+ receiving the structured hash. See
  #    +spec/lib/unified_health_data/concerns/clinical_notes_logging_spec.rb+.
  #
  class MedicalRecordsLog
    SERVICE_NAME = 'medical_records'

    # ── Resource domain constants ──
    # Use these instead of raw strings to avoid typos and improve grep-ability.
    # When adding a new domain, add a constant here and reference it in DOMAIN_TOGGLES.
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
    #
    # To add a new domain: add a mapping here AND register the toggle in config/features.yml.
    # Naming convention: :mhv_medical_records_<domain>_diagnostic
    #
    # Domains without an entry here still work — they just rely on the global toggle only.
    DOMAIN_TOGGLES = {
      CLINICAL_NOTES => :mhv_medical_records_clinical_notes_diagnostic,
      LABS_AND_TESTS => :mhv_medical_records_labs_and_tests_diagnostic
    }.freeze

    # Keys that are always stripped from log output. Checked case-insensitively.
    # Sourced from the User model (app/models/user.rb) — covers identity fields,
    # VA/DoD identifiers, and authentication UUIDs.
    PII_KEYS = %i[
      icn
      ssn
      social_security_number
      email
      mhv_correlation_id
      first_name
      middle_name
      last_name
      birth_date
      date_of_birth
      address
      phone
      phone_number
      home_phone
      edipi
      birls_id
      participant_id
      sec_id
      user_uuid
      idme_uuid
      logingov_uuid
      vet360_id
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
    # @param metadata [Hash] Additional structured data to include in the log entry
    def info(resource:, action:, **metadata)
      write(:info, resource:, action:, **metadata)
    end

    # Always-on warn-level log.
    # Use for anomalies, unexpected states, or degraded-but-functional conditions.
    #
    # @param resource [String] The medical record resource type
    # @param action [String] The controller/service action
    # @param metadata [Hash] Additional structured data
    def warn(resource:, action:, **metadata)
      write(:warn, resource:, action:, **metadata)
    end

    # Always-on error-level log.
    # Use for failures that prevent a response from being returned.
    #
    # @param resource [String] The medical record resource type
    # @param action [String] The controller/service action
    # @param metadata [Hash] Additional structured data
    def error(resource:, action:, **metadata)
      write(:error, resource:, action:, **metadata)
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
    def diagnostic(resource:, action:, **metadata)
      return false unless diagnostic_enabled?(resource)

      write(:info, resource:, action:, log_level_context: 'diagnostic', **metadata)
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
    def write(level, resource:, action:, **metadata)
      payload = build_payload(resource:, action:, **metadata)
      Rails.logger.public_send(level, payload)
    end

    # Assembles the canonical log hash.
    def build_payload(resource:, action:, **metadata)
      sanitized = strip_pii(metadata)

      {
        service: SERVICE_NAME,
        resource:,
        action:,
        **sanitized
      }
    end

    # Recursively removes any keys from the hash that match PII_KEYS.
    # Operates on a deep copy so the caller's hash is not mutated.
    def strip_pii(hash)
      hash.each_with_object({}) do |(key, value), clean|
        sym_key = key.to_s.downcase.to_sym
        next if PII_KEYS.include?(sym_key)

        clean[key] = case value
                     when Hash
                       strip_pii(value)
                     when Array
                       value.map { |v| v.is_a?(Hash) ? strip_pii(v) : v }
                     else
                       value
                     end
      end
    end
  end
end
