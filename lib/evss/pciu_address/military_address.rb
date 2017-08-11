# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class MilitaryAddress < Address
      attribute :military_post_office_type_code, String
      attribute :military_state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String
    end
  end
end
