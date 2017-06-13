# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module Letters
    class Address < Common::Base
      attribute :full_name, String
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, String
      attribute :state, String
      attribute :country, String
      attribute :foreign_code, String
      attribute :zip_code, String
    end
  end
end
