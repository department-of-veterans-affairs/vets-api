# frozen_string_literal: true

module Vass
  ##
  # Constants for StatsD metrics tracking throughout the VASS module.
  #
  # Naming Convention: api.vass.{layer}.{component}.{action}.{outcome}
  #
  # Layers:
  #   - controller: User-facing API endpoints (success/failure)
  #   - infrastructure: Rate limiting, OTP/session lifecycle, VANotify
  #
  # Controller Metrics (7 endpoints × 2 outcomes = 14 metrics):
  #   Each endpoint tracks: .success, .failure
  #
  # Infrastructure Metrics (4 metrics):
  #   OTP lifecycle (expired/invalid), rate limiting (generation/validation)
  #
  # Tags (consistent across all metrics):
  #   - service:vass (always present)
  #   - endpoint:{action_name} (controller metrics)
  #   - http_method:{GET|POST} (controller metrics)
  #   - http_status:{200|400|401|404|500|502} (controller metrics)
  #   - error_type:{ErrorClassName} (failure metrics only)
  #
  module MetricsConstants
    # Base prefixes
    METRIC_PREFIX = 'api.vass'
    CONTROLLER_PREFIX = "#{METRIC_PREFIX}.controller".freeze
    SERVICE_PREFIX = "#{METRIC_PREFIX}.service".freeze
    INFRASTRUCTURE_PREFIX = "#{METRIC_PREFIX}.infrastructure".freeze

    # Service identification
    SERVICE_TAG = 'service:vass'

    # Outcome suffixes
    SUCCESS = 'success'
    FAILURE = 'failure'

    # ========================================
    # Controller Metrics - Sessions
    # ========================================
    SESSIONS_REQUEST_OTP = "#{CONTROLLER_PREFIX}.sessions.request_otp".freeze
    SESSIONS_AUTHENTICATE_OTP = "#{CONTROLLER_PREFIX}.sessions.authenticate_otp".freeze
    SESSIONS_REVOKE_TOKEN = "#{CONTROLLER_PREFIX}.sessions.revoke_token".freeze

    # ========================================
    # Controller Metrics - Appointments
    # ========================================
    APPOINTMENTS_AVAILABILITY = "#{CONTROLLER_PREFIX}.appointments.availability".freeze
    APPOINTMENTS_CREATE = "#{CONTROLLER_PREFIX}.appointments.create".freeze
    APPOINTMENTS_SHOW = "#{CONTROLLER_PREFIX}.appointments.show".freeze
    APPOINTMENTS_CANCEL = "#{CONTROLLER_PREFIX}.appointments.cancel".freeze
    APPOINTMENTS_TOPICS = "#{CONTROLLER_PREFIX}.appointments.topics".freeze

    # ========================================
    # Infrastructure Metrics - Rate Limiting
    # ========================================
    RATE_LIMIT_GENERATION_EXCEEDED = "#{INFRASTRUCTURE_PREFIX}.rate_limit.generation.exceeded".freeze
    RATE_LIMIT_VALIDATION_EXCEEDED = "#{INFRASTRUCTURE_PREFIX}.rate_limit.validation.exceeded".freeze

    # ========================================
    # Infrastructure Metrics - Session/OTP
    # ========================================
    SESSION_OTP_EXPIRED = "#{INFRASTRUCTURE_PREFIX}.session.otp.expired".freeze
    SESSION_OTP_INVALID = "#{INFRASTRUCTURE_PREFIX}.session.otp.invalid".freeze
    SESSION_JWT_EXPIRED = "#{INFRASTRUCTURE_PREFIX}.session.jwt.expired".freeze

    # ========================================
    # Infrastructure Metrics - Auth Failures
    # ========================================
    AUTH_IDENTITY_VALIDATION_FAILURE = "#{INFRASTRUCTURE_PREFIX}.auth.identity_validation.failure".freeze

    # ========================================
    # Infrastructure Metrics - Availability Scenarios
    # ========================================
    AVAILABILITY_NO_COHORTS = "#{INFRASTRUCTURE_PREFIX}.availability.no_cohorts".freeze
    AVAILABILITY_NEXT_COHORT = "#{INFRASTRUCTURE_PREFIX}.availability.next_cohort".freeze
    AVAILABILITY_ALREADY_BOOKED = "#{INFRASTRUCTURE_PREFIX}.availability.already_booked".freeze
    AVAILABILITY_NO_SLOTS = "#{INFRASTRUCTURE_PREFIX}.availability.no_slots_available".freeze
  end
end
