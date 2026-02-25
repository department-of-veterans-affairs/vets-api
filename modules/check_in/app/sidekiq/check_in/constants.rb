# frozen_string_literal: true

module CheckIn
  module Constants
    LOG_PREFIX = 'Check-In V1 Travel Claim'

    # settings for travel claims for vista appts
    STATSD_NOTIFY_ERROR = 'worker.checkin.travel_claim.notify.error'
    STATSD_NOTIFY_SUCCESS = 'worker.checkin.travel_claim.notify.success'
    STATSD_NOTIFY_DELIVERED = 'worker.checkin.travel_claim.notify.delivered'
    STATSD_NOTIFY_SILENT_FAILURE = 'silent_failure'
    STATSD_CIE_SILENT_FAILURE_TAGS = ['service:check-in',
                                      'function: CheckIn Travel Pay Notification Failure'].freeze
    STATSD_OH_SILENT_FAILURE_TAGS = ['service:check-in',
                                     'function: OH Travel Pay Notification Failure'].freeze

    CIE_SUCCESS_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_success_text
    CIE_DUPLICATE_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_duplicate_text
    CIE_ERROR_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_error_text
    CIE_FAILURE_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_failure_text
    CIE_TIMEOUT_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_timeout_text

    CIE_SMS_SENDER_ID = Settings.vanotify.services.check_in.sms_sender_id

    CIE_STATSD_BTSSS_SUCCESS = 'worker.checkin.travel_claim.btsss.success'
    CIE_STATSD_BTSSS_ERROR = 'worker.checkin.travel_claim.btsss.error'
    CIE_STATSD_BTSSS_TIMEOUT = 'worker.checkin.travel_claim.btsss.timeout'
    CIE_STATSD_BTSSS_CLAIM_FAILURE = 'worker.checkin.travel_claim.btsss.claim.failure'
    CIE_STATSD_BTSSS_DUPLICATE = 'worker.checkin.travel_claim.btsss.duplicate'

    # settings for travel claims for oracle health appts
    OH_SUCCESS_TEMPLATE_ID = Settings.vanotify.services.oracle_health.template_id.claim_submission_success_text
    OH_DUPLICATE_TEMPLATE_ID = Settings.vanotify.services.oracle_health.template_id.claim_submission_duplicate_text
    OH_ERROR_TEMPLATE_ID = Settings.vanotify.services.oracle_health.template_id.claim_submission_error_text
    OH_FAILURE_TEMPLATE_ID = Settings.vanotify.services.oracle_health.template_id.claim_submission_failure_text
    OH_TIMEOUT_TEMPLATE_ID = Settings.vanotify.services.oracle_health.template_id.claim_submission_timeout_text

    OH_SMS_SENDER_ID = Settings.vanotify.services.oracle_health.sms_sender_id

    OH_STATSD_BTSSS_SUCCESS = 'worker.oracle_health.travel_claim.btsss.success'
    OH_STATSD_BTSSS_ERROR = 'worker.oracle_health.travel_claim.btsss.error'
    OH_STATSD_BTSSS_TIMEOUT = 'worker.oracle_health.travel_claim.btsss.timeout'
    OH_STATSD_BTSSS_CLAIM_FAILURE = 'worker.oracle_health.travel_claim.btsss.claim.failure'
    OH_STATSD_BTSSS_DUPLICATE = 'worker.oracle_health.travel_claim.btsss.duplicate'

    # V1 specific Travel Claim Submission Step Metrics - CIE
    CIE_STATSD_APPOINTMENT_ERROR = 'api.check_in.travel_claim.appointment.error'
    CIE_STATSD_CLAIM_CREATE_ERROR = 'api.check_in.travel_claim.claim.create.error'
    CIE_STATSD_EXPENSE_ADD_ERROR = 'api.check_in.travel_claim.expense.add.error'
    CIE_STATSD_CLAIM_SUBMIT_ERROR = 'api.check_in.travel_claim.claim.submit.error'

    # Travel Claim Submission Step Metrics - OH
    OH_STATSD_APPOINTMENT_ERROR = 'api.oracle_health.travel_claim.appointment.error'
    OH_STATSD_CLAIM_CREATE_ERROR = 'api.oracle_health.travel_claim.claim.create.error'
    OH_STATSD_EXPENSE_ADD_ERROR = 'api.oracle_health.travel_claim.expense.add.error'
    OH_STATSD_CLAIM_SUBMIT_ERROR = 'api.oracle_health.travel_claim.claim.submit.error'

    # Auth failure metrics
    CIE_STATSD_AUTH_FAILURE = 'api.check_in.travel_claim.auth.failure'
    OH_STATSD_AUTH_FAILURE = 'api.oracle_health.travel_claim.auth.failure'

    # Validation error metrics
    CIE_STATSD_VALIDATION_ERROR = 'api.check_in.travel_claim.validation.error'
    OH_STATSD_VALIDATION_ERROR = 'api.oracle_health.travel_claim.validation.error'

    # V1 outcome metrics - CIE
    CIE_STATSD_BTSSS_V1_SUCCESS = 'api.check_in.travel_claim.btsss.v1.success'
    CIE_STATSD_BTSSS_V1_CLAIM_FAILURE = 'api.check_in.travel_claim.btsss.v1.claim.failure'
    CIE_STATSD_BTSSS_V1_DUPLICATE = 'api.check_in.travel_claim.btsss.v1.duplicate'

    # V1 outcome metrics - OH
    OH_STATSD_BTSSS_V1_SUCCESS = 'api.oracle_health.travel_claim.btsss.v1.success'
    OH_STATSD_BTSSS_V1_CLAIM_FAILURE = 'api.oracle_health.travel_claim.btsss.v1.claim.failure'
    OH_STATSD_BTSSS_V1_DUPLICATE = 'api.oracle_health.travel_claim.btsss.v1.duplicate'

    # Error notification dispatched
    CIE_STATSD_ERROR_NOTIFICATION = 'api.check_in.travel_claim.error_notification'
    OH_STATSD_ERROR_NOTIFICATION = 'api.oracle_health.travel_claim.error_notification'

    # Check-in eligibility and demographics tracking
    STATSD_CHECKIN_DATA_RETRIEVED = 'api.check_in.data.retrieved'
    STATSD_CHECKIN_ELIGIBILITY = 'api.check_in.appointment.eligibility'
    STATSD_CHECKIN_DEMOGRAPHICS_STATUS = 'api.check_in.demographics.status'
  end
end
