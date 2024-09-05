# frozen_string_literal: true

module CheckIn
  module Constants
    # settings for travel claims for vista appts
    STATSD_NOTIFY_ERROR = 'worker.checkin.travel_claim.notify.error'
    STATSD_NOTIFY_SUCCESS = 'worker.checkin.travel_claim.notify.success'

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
  end
end
