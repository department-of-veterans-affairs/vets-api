# frozen_string_literal: true

module SAML
  class SAMLError < StandardError
    attr_reader :code, :tag, :level, :context
  end

  class UserAttributeError < SAMLError
    MULTIPLE_MHV_IDS_CODE = '101'
    MULTIPLE_EDIPIS_CODE = '102'
    MHV_ICN_MISMATCH_CODE = '103'
    UUID_MISSING_CODE = '104'
    MULTPLE_CORP_IDS_CODE = '106'
    MHV_UNVERIFIED_BLOCKED_CODE = '108'
    SSN_MISMATCH_CODE = '113'

    ERRORS = {
      multiple_mhv_ids: { code: MULTIPLE_MHV_IDS_CODE,
                          tag: :multiple_mhv_ids,
                          message: 'User attributes contain multiple distinct MHV ID values' }.freeze,
      multiple_edipis: { code: MULTIPLE_EDIPIS_CODE,
                         tag: :multiple_edipis,
                         message: 'User attributes contain multiple distinct EDIPI values' }.freeze,
      mhv_icn_mismatch: { code: MHV_ICN_MISMATCH_CODE,
                          tag: :mhv_icn_mismatch,
                          message: 'MHV credential ICN does not match MPI record' }.freeze,
      uuid_missing: { code: UUID_MISSING_CODE,
                      tag: :uuid_missing,
                      message: 'User attributes is missing an ID.me and Login.gov UUID' }.freeze,
      multiple_corp_ids: { code: MULTPLE_CORP_IDS_CODE,
                           tag: :multiple_corp_ids,
                           message: 'User attributes contain multiple distinct CORP ID values' }.freeze,
      mhv_unverified_blocked: { code: MHV_UNVERIFIED_BLOCKED_CODE,
                                tag: :mhv_unverified_blocked,
                                message: 'MHV account is unverified for context requiring verified account' }.freeze,
      ssn_mismatch: { code: SSN_MISMATCH_CODE,
                      tag: :ssn_mismatch,
                      message: "Attribute mismatch: ssn in primary view doesn't match correlation record" }.freeze
    }.freeze

    attr_reader :identifier

    def initialize(message:, code:, tag:, context: {}, identifier: nil)
      @code = code
      @tag = tag
      @level = :warning
      @context = context
      @identifier = identifier
      super(message)
    end
  end

  class FormError < SAMLError
    def initialize(form, code = {})
      @code = code || form.error_code
      @tag = form.error_instrumentation_code
      @level = form.errors_hash[:level]
      @context = form.errors_context
      super(form.errors_message)
    end
  end
end
