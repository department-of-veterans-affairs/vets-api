# frozen_string_literal: true

module DecisionReviewV1
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
end
