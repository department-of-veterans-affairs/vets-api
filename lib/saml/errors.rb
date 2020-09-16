# frozen_string_literal: true

module SAML
  class SAMLError < StandardError
    attr_reader :code, :tag, :level, :context
  end

  class UserAttributeError < SAMLError
    ERRORS = {
      multiple_mhv_ids: { code: '101',
                          tag: :multiple_mhv_ids,
                          message: 'User attributes contain multiple distinct MHV ID values' }.freeze,
      multiple_edipis: { code: '102',
                         tag: :multiple_edipis,
                         message: 'User attributes contain multiple distinct EDIPI values' }.freeze,
      mhv_icn_mismatch: { code: '103',
                          tag: :mhv_icn_mismatch,
                          message: 'MHV credential ICN does not match MPI record' }.freeze,
      idme_uuid_missing: { code: '104',
                           tag: :idme_uuid_missing,
                           message: 'User attributes is missing an ID.me UUID' }.freeze
    }.freeze

    attr_reader :identifier

    def initialize(message:, code:, tag:, identifier: nil)
      @code = code
      @tag = tag
      @level = :warning
      @context = {}
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
