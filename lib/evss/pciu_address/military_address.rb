# frozen_string_literal: true

require_relative 'address'

module EVSS
  module PCIUAddress
    ##
    # Model for military addresses
    #
    # @!attribute military_post_office_type_code
    #   @return [String] The type of military post office; one of %w[APO FPO DPO]
    # @!attribute military_state_code
    #   return [String] The military state code; one of %w[AA AE AP]
    # @!attribute zip_code
    #   @return [String] Zip code (exactly 5 digits)
    # @!attribute zip_suffix
    #   @return [String] Zip code suffix (exactly 4 digits with optional leading dash)
    #
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
