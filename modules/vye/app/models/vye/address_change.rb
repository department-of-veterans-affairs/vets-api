# frozen_string_literal: true

module Vye; end

class Vye::AddressChange < ApplicationRecord
  belongs_to :user_info

  ENCRYPTED_ATTRIBUTES = %i[
    address1 address2 address3 address4 city state veteran_name zip_code
  ].freeze

  has_kms_key
  has_encrypted(*ENCRYPTED_ATTRIBUTES, key: :kms_key, **lockbox_options)

  REQUIRED_ATTRIBUTES = [
    *ENCRYPTED_ATTRIBUTES,
    *%i[benefit_type rpo].freeze
  ].freeze

  validates(*REQUIRED_ATTRIBUTES, presence: true)
end
