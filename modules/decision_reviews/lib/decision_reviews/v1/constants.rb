# frozen_string_literal: true

module DecisionReviews
  module V1
    SC_REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze
    SC_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'SC-CREATE-RESPONSE-200_V1'
    SC_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'SC-SHOW-RESPONSE-200_V2'

    FORM4142_ID = '4142'
    FORM_ID = '21-4142'
    SUPP_CLAIM_FORM_ID = '20-0995'

    NOD_REQUIRED_CREATE_HEADERS = %w[X-VA-File-Number X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date].freeze
    NOD_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'NOD-CREATE-RESPONSE-200_V1'
    NOD_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'NOD-SHOW-RESPONSE-200_V2'

    HLR_REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze
    HLR_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-CREATE-RESPONSE-200_V1'
    HLR_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-SHOW-RESPONSE-200_V2'

    # TODO: rename the imported schema as its shared with Supplemental Claims
    GET_LEGACY_APPEALS_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-GET-LEGACY-APPEALS-RESPONSE-200'

    GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA =
      VetsJsonSchema::SCHEMAS.fetch 'DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1'

    TEMPLATE_IDS = Settings.vanotify.services.benefits_decision_review.template_id

    FORM_TEMPLATE_IDS = {
      'HLR' => TEMPLATE_IDS.higher_level_review_form_error_email,
      'NOD' => TEMPLATE_IDS.notice_of_disagreement_form_error_email,
      'SC' => TEMPLATE_IDS.supplemental_claim_form_error_email
    }.freeze

    EVIDENCE_TEMPLATE_IDS = {
      'NOD' => TEMPLATE_IDS.notice_of_disagreement_evidence_error_email,
      'SC' => TEMPLATE_IDS.supplemental_claim_evidence_error_email
    }.freeze

    SECONDARY_FORM_TEMPLATE_ID = TEMPLATE_IDS.supplemental_claim_secondary_form_error_email

    APPEAL_TYPE_TO_SERVICE_MAP = {
      'HLR' => 'higher-level-review',
      'NOD' => 'board-appeal',
      'SC' => 'supplemental-claims'
    }.freeze

    EMAIL_RESULT_LOGGING_CONFIG = {
      form: {
        log_message: 'form email queued',
        statsd_key: 'form.email_queued',
        error_statsd_key: 'form.error',
        function: 'form submission to Lighthouse',
        params_builder: lambda { |submission, extra_data|
          {
            submitted_appeal_uuid: submission.submitted_appeal_uuid,
            appeal_type: submission.type_of_appeal,
            notification_id: extra_data
          }
        },
        error_params_builder: lambda { |submission, error_message|
          {
            submitted_appeal_uuid: submission.submitted_appeal_uuid,
            appeal_type: submission.type_of_appeal,
            message: error_message
          }
        }
      },
      evidence: {
        log_message: 'evidence email queued',
        statsd_key: 'evidence.email_queued',
        error_statsd_key: 'evidence.error',
        function: 'evidence submission to Lighthouse',
        params_builder: lambda { |upload, extra_data|
          submission = upload.appeal_submission
          {
            submitted_appeal_uuid: submission.submitted_appeal_uuid,
            lighthouse_upload_id: upload.lighthouse_upload_id,
            appeal_type: submission.type_of_appeal,
            notification_id: extra_data
          }
        },
        error_params_builder: lambda { |upload, error_message|
          submission = upload.appeal_submission
          {
            submitted_appeal_uuid: submission.submitted_appeal_uuid,
            lighthouse_upload_id: upload.lighthouse_upload_id,
            appeal_type: submission.type_of_appeal,
            message: error_message
          }
        }
      },
      secondary_form: {
        log_message: 'secondary form email queued',
        statsd_key: 'secondary_form.email_queued',
        error_statsd_key: 'secondary_form.error',
        function: 'secondary form submission to Lighthouse',
        params_builder: lambda { |form, extra_data|
          submission = form.appeal_submission
          {
            submitted_appeal_uuid: submission.submitted_appeal_uuid,
            lighthouse_upload_id: form.guid,
            appeal_type: submission.type_of_appeal,
            notification_id: extra_data
          }
        },
        error_params_builder: lambda { |form, error_message|
          submission = form.appeal_submission
          {
            submitted_appeal_uuid: submission.submitted_appeal_uuid,
            lighthouse_upload_id: form.guid,
            appeal_type: submission.type_of_appeal,
            message: error_message
          }
        }
      }
    }.freeze
  end
end
