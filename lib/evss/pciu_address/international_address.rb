# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class InternationalAddress < Address
      attribute :foreign_code, String

      validates :city, presence: true
      validates :country_name, presence: true
    end
  end
end
