# frozen_string_literal: true

module EVSS
  module PCIU
    class PhoneNumber < BaseModel
      attribute :country_code, String
      attribute :number, String
      attribute :extension, String
      attribute :effective_date, DateTime

      validates :number, presence: true
      validates :number, format: { with: /\A\d+\z/, message: 'Only numbers are permitted.' }
    end
  end
end
