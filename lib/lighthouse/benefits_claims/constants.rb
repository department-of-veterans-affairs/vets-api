# frozen_string_literal: true

module BenefitsClaims
  module Constants
    CLAIM_TYPE_LANGUAGE_MAP = {
      'Death' => 'expenses related to death or burial'
    }.freeze

    # These are evidence requests that should not be displayed to the user when:
    # - `cst_suppress_evidence_requests_website` feature flag is enabled
    # - `cst_suppress_evidence_requests_mobile` feature flag is enabled
    # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/126870
    SUPPRESSED_EVIDENCE_REQUESTS = [
      'Admin Decision',
      'ADMINCOD',
      'Attorney Fee',
      'Attorney Fee Release',
      'Awaiting Upload of Hearing Transcript',
      'Delayed BDD Exam Requests',
      'Exam Request - Processing',
      'Exam Review - Not Performed',
      'Exam Review - Partially Complete',
      'IT Ticket-Exam Control Issue',
      'ND Additional Action Required',
      'Pending Completion of Concurrent EP',
      'Rating Extraschedular Memorandum',
      'Records Research Task',
      'Resolution of Pending Rating EP',
      'RO Research Coordinator Review',
      'Second Signature',
      'Secondary Action Required',
      'Stage 2 Development' # Not currently used by VBMS but will eventually replace `Secondary Action Required`
    ].freeze

    FIRST_PARTY_AS_THIRD_PARTY_OVERRIDES = [
      'PMR Pending',
      'Proof of service (DD214, etc.)',
      'NG1 - National Guard Records Request',
      'VHA Outpatient Treatment Records (10-7131)',
      'HAIMS STR Follow-up',
      'Audit Request'
    ].freeze
  end
end
