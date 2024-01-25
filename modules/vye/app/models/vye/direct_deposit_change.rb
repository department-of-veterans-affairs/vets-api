# frozen_string_literal: true

module Vye
  class Vye::DirectDepositChange < ApplicationRecord
    belongs_to :user_info

    ENCRYPTED_ATTRIBUTES = %i[
      acct_no acct_type bank_name bank_phone chk_digit email full_name phone phone2 routing_no
    ].freeze

    has_kms_key
    has_encrypted(*ENCRYPTED_ATTRIBUTES, key: :kms_key, **lockbox_options)

    REQUIRED_ATTRIBUTES = [
      *ENCRYPTED_ATTRIBUTES,
      *%i[ben_type rpo].freeze
    ].freeze

    validates(*REQUIRED_ATTRIBUTES, presence: true)
  end
end
