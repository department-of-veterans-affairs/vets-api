# frozen_string_literal: true

module EVSS
  module PCIU
    class PhoneNumber < BaseModel
      attribute :country_code, String
      attribute :number, String
      attribute :extension, String
      attribute :effective_date, DateTime

      validates :country_code, :number, :extension, presence: true
    end
  end
end
