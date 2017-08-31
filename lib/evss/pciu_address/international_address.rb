# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class InternationalAddress < Address
      validates :city, presence: true
      validates :country_name, presence: true
    end
  end
end
