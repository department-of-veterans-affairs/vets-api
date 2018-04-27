# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class DomesticAddress < Address
      attribute :city, String
      attribute :state_code, String
      attribute :country_name, String
      attribute :zip_code, String
      attribute :zip_suffix, String

      validates :city, pciu_address_line: true, presence: true, length: { maximum: 30 }
      validates :state_code, presence: true
      validates :zip_code, presence: true

      validates_format_of :zip_code, with: ZIP_CODE_REGEX
      validates_format_of :zip_suffix, with: ZIP_SUFFIX_REGEX, allow_blank: true
    end
  end
end
