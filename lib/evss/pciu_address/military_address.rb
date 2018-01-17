# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class MilitaryAddress < Address
      MILITARY_POST_OFFICE_TYPES = %w[APO FPO DPO].freeze
      MILITARY_STATE_CODES = %w[AA AE AP].freeze

      attribute :military_post_office_type_code, String
      attribute :military_state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String

      validates :zip_code, presence: true
      validates :military_post_office_type_code, presence: true, inclusion: { in: MILITARY_POST_OFFICE_TYPES }
      validates :military_state_code, presence: true, inclusion: { in: MILITARY_STATE_CODES }

      validates_format_of :zip_code, with: ZIP_CODE_REGEX
      validates_format_of :zip_suffix, with: ZIP_SUFFIX_REGEX, allow_blank: true
    end
  end
end
