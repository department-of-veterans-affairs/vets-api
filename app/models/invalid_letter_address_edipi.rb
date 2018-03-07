# frozen_string_literal: true

class InvalidLetterAddressEdipi < ActiveRecord::Base
  validates :edipi, presence: true, uniqueness: true
end
