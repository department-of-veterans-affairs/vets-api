# frozen_string_literal: true

class InvalidLetterAddressEdipi < ApplicationRecord
  validates :edipi, presence: true, uniqueness: true
end
