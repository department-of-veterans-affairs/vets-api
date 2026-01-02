# frozen_string_literal: true

require 'vets/model'

module ClaimLetters
  module Responses
    DOCTYPE_TO_TYPE_DESCRIPTION = {
      '27' => 'Board decision',
      '34' => 'Request for specific evidence or information',
      '184' => 'Claim decision (or other notification, like Intent to File)',
      '408' => 'Notification: Exam with VHA has been scheduled',
      '700' => 'Request for specific evidence or information',
      '704' => 'List of evidence we may need ("5103 notice")',
      '706' => 'List of evidence we may need ("5103 notice")',
      '858' => 'List of evidence we may need ("5103 notice")',
      '859' => 'Request for specific evidence or information',
      '864' => 'Copy of request for medical records sent to a non-VA provider',
      '942' => 'Final notification: Request for specific evidence or information',
      '1605' => 'Copy of request for non-medical records sent to a non-VA organization'
    }.freeze

    # 27: Board Of Appeals Decision Letter
    # 34: Correspondence
    # 184: Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)
    # 408: VA Examination Letter
    # 700: MAP-D Development letter
    # 704: Standard 5103 Notice
    # 706: 5103/DTA Letter
    # 858: Custom 5103 Notice
    # 859: Subsequent Development letter
    # 864: General Records Request (Medical)
    # 942: Final Attempt Letter
    # 1605: General Records Request (Non-Medical)
    def self.default_allowed_doctypes(user = nil)
      doctypes = %w[184]
      doctypes << '27' if Flipper.enabled?(:cst_include_ddl_boa_letters, user)
      doctypes << '704' if Flipper.enabled?(:cst_include_ddl_5103_letters, user)
      doctypes << '706' if Flipper.enabled?(:cst_include_ddl_5103_letters, user)
      doctypes << '858' if Flipper.enabled?(:cst_include_ddl_5103_letters, user)
      doctypes << '34' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes << '408' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes << '700' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes << '859' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes << '864' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes << '942' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes << '1605' if Flipper.enabled?(:cst_include_ddl_sqd_letters, user)
      doctypes
    end

    class ClaimLetterResponse
      include Vets::Model

      attribute :document_id, String
      attribute :series_id, String
      attribute :version, String
      attribute :type_description, String
      attribute :type_id, String
      attribute :doc_type, String
      attribute :subject, String
      attribute :received_at, String
      attribute :source, String
      attribute :mime_type, String
      attribute :alt_doc_types, String
      attribute :restricted, Bool
      attribute :upload_date, String
    end

    class ClaimLetterDownloadResponse
      include Vets::Model
    end
  end
end
