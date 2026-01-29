# frozen_string_literal: true

module CheckIn
  module Constants
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

    # Check-in eligibility and demographics tracking
    STATSD_CHECKIN_DATA_RETRIEVED = 'api.check_in.data.retrieved'
    STATSD_CHECKIN_ELIGIBILITY = 'api.check_in.appointment.eligibility'
    STATSD_CHECKIN_DEMOGRAPHICS_STATUS = 'api.check_in.demographics.status'
  end
end
