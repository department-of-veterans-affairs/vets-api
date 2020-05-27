# frozen_string_literal: true

module SAML
  class UserAttributeError < StandardError
    MULTIPLE_MHV_IDS = { code: '101',
                         tag: :multiple_mhv_ids,
                         message: 'User attributes contain multiple distinct MHV ID values' }.freeze
    MULTIPLE_EDIPIS = { code: '102',
                        tag: :multiple_edipis,
                        message: 'User attributes contain multiple distinct EDIPI values' }.freeze
    MHV_ICN_MISMATCH = { code: '103',
                         tag: :mhv_icn_mismatch,
                         message: 'MHV credential ICN does not match MPI record' }.freeze
    IDME_UUID_MISSING = { code: '104',
                          tag: :idme_uuid_missing,
                          message: 'User attributes is missing an ID.me UUID' }.freeze

    attr_reader :code, :tag

    def initialize(message:, code:, tag:)
      @code = code
      @tag = tag
      super(message)
    end
  end
end
