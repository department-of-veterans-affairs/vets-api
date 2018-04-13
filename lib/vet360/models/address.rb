# frozen_string_literal: true

module Vet360
  module Models
    class Address < Base
      attribute :address_line_1, String
      attribute :address_line_2, String
      attribute :address_line_3, String
      attribute :address_pou, String  # purpose of use
      attribute :address_type, String
      attribute :city, String
      attribute :confirmation_date, Common::ISO8601Time
      attribute :country, String
      attribute :country_code_iso2, String
      attribute :country_code_iso3, String
      attribute :county_code, String
      attribute :county_name, String
      attribute :created_at, Common::ISO8601Time
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
      attribute :id, Integer
      attribute :international_postal_code, String
      attribute :source_date, Common::ISO8601Time
      attribute :state_abbr, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :zip_code, String
      attribute :zip_code_suffix, String

      validates :source_date, presence: true

      def self.from_response(body)
        # TODO: Map address response object to model
        Vet360::Models::Address.new
      end
    end
  end
end
