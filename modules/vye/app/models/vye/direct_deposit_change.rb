# frozen_string_literal: true

module Vye
  class Vye::DirectDepositChange < ApplicationRecord
    belongs_to :user_info

    ENCRYPTED_ATTRIBUTES = %i[
      acct_no acct_type bank_name bank_phone email full_name routing_no phone phone2 chk_digit
    ].freeze

    has_kms_key
    has_encrypted(*ENCRYPTED_ATTRIBUTES, key: :kms_key, **lockbox_options)

    REQUIRED_ATTRIBUTES = %i[
      acct_no acct_type bank_name bank_phone email full_name routing_no phone
    ].freeze

    validates(*REQUIRED_ATTRIBUTES, presence: true)
  end
end
