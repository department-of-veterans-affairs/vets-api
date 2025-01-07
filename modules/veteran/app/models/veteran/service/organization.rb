# frozen_string_literal: true

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Organization < ApplicationRecord
      self.primary_key = :poa

      validates :poa, presence: true

      #
      # Compares rep's current info with new data to detect changes in address, email, or phone number.
      # @param rep_data [Hash] New data with :email, :phone_number, and :address keys for comparison.
      #
      # @return [Hash] Hash with "email_changed", "phone_number_changed", "address_changed" keys as booleans.
      def diff(rep_data)
        %i[address phone_number].each_with_object({}) do |field, diff|
          diff["#{field}_changed"] = field == :address ? address_changed?(rep_data) : send(field) != rep_data[field]
        end
      end

      private

      #
      # Checks if the rep's address has changed compared to a new address hash.
      # @param other_address [Hash] New address data with keys for address components and state code.
      #
      # @return [Boolean] True if current address differs from `other_address`, false otherwise.
      def address_changed?(rep_data)
        address = [address_line1, address_line2, address_line3, city, zip_code, zip_suffix, state_code].join(' ')
        other_address = rep_data[:address]
                        .values_at(:address_line1, :address_line2, :address_line3, :city, :zip_code5, :zip_code4)
                        .push(rep_data.dig(:address, :state_province, :code))
                        .join(' ')
        address != other_address
      end
    end
  end
end
