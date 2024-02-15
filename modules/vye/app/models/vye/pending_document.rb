# frozen_string_literal: true

module Vye
  class Vye::PendingDocument < ApplicationRecord
    include Vye::GenDigest

    belongs_to :user_info, foreign_key: :ssn_digest, primary_key: :ssn_digest, inverse_of: :pending_documents

    ENCRYPTED_ATTRIBUTES = %i[claim_no ssn].freeze

    has_kms_key
    has_encrypted(*ENCRYPTED_ATTRIBUTES, key: :kms_key, **lockbox_options)

    REQUIRED_ATTRIBUTES = [
      *ENCRYPTED_ATTRIBUTES,
      *%i[doc_type queue_date rpo ssn_digest].freeze
    ].freeze

    validates(*REQUIRED_ATTRIBUTES, presence: true)

    before_validation :digest_ssn

    private

    def digest_ssn
      self.ssn_digest = gen_digest(ssn) if ssn_changed?
    end
  end
end
