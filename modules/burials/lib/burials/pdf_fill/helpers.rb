# frozen_string_literal: true

module Burials
  module PdfFill
    # Helpers used for PDF mapping
    module Helpers
      ##
      # Expands a date range from a hash into start and end date fields
      #
      # @param hash [Hash]
      # @param key [Symbol]
      #
      # @return [Hash]
      #
      def expand_date_range(hash, key)
        return if hash.blank?

        date_range = hash[key]
        return if date_range.blank?

        hash["#{key}Start"] = date_range['from']
        hash["#{key}End"] = date_range['to']
        hash.delete(key)

        hash
      end

      ##
      # Combines multiple fields from a hash into a single string
      #
      # @param hash [Hash]
      # @param keys [Array<String, Symbol>]
      # @param separator [String]
      #
      # @return [String]
      #
      def combine_hash(hash, keys, separator = ' ')
        return if hash.blank?

        keys
          .map { |key| hash[key] }
          .compact_blank # removes both nil and empty strings
          .join(separator)
      end

      ##
      # Combines a full name from its components into a single string
      #
      # @param full_name [Hash]
      #
      # @return [String]
      #
      def combine_full_name(full_name)
        combine_hash(full_name, %w[first middle last suffix])
      end

      ##
      # Converts a boolean value into a checkbox selection
      #
      # This method returns 'On' if the value is truthy, otherwise it returns 'Off'
      # Override for on/off vs 1/off @see FormHelper
      #
      # @param value [Boolean]
      #
      # @return [String]
      def select_checkbox(value)
        value ? 'On' : 'Off'
      end

      ##
      # Converts a boolean value into a radio selection
      #
      # This method returns 0 for true and 1 for false and nil for nil
      # This behavior stems from VBA's request to keep boolean fields blank
      # on the PDF if not selected on the online form.
      #
      # For more context, see this PR: https://github.com/department-of-veterans-affairs/vets-api/pull/22958
      #
      # @param value [Boolean, nil]
      #
      # @return [Integer, nil]
      def select_radio(value)
        return nil if value.nil?

        value ? 0 : 1
      end

      ##
      # Expands a value from a hash into a 'checkbox' structure
      #
      # Override for 'On' vs true @see FormHelper
      #
      # @param hash [Hash]
      # @param key [Symbol]
      #
      # @return [void]
      def expand_checkbox_as_hash(hash, key)
        value = hash.try(:[], key)
        return if value.blank?

        hash['checkbox'] = {
          value => 'On'
        }
      end

      ##
      # This method sanitizes a phone number by removing dashes
      #
      # @param phone [String] The phone number to be sanitized.
      #
      # @return [String]
      def sanitize_phone(phone)
        phone.gsub('-', '')
      end

      ##
      # Splits a phone number from a hash into its component parts
      #
      # @param hash [Hash]
      # @param key [String, Symbol]
      #
      # @return [Hash]
      def split_phone(hash, key)
        phone = hash[key]
        return if phone.blank?

        phone = sanitize_phone(phone)
        hash[key] = {
          'first' => phone[0..2],
          'second' => phone[3..5],
          'third' => phone[6..9]
        }
      end

      ##
      # Splits a postal code into its first five and last four digits if present
      # If the postal code is blank, the method returns nil
      #
      # @param hash [Hash]
      #
      # @return [Hash]
      def split_postal_code(hash)
        postal_code = hash['claimantAddress']['postalCode']
        return if postal_code.blank?

        hash['claimantAddress']['postalCode'] = {
          'firstFive' => postal_code[0..4],
          'lastFour' => postal_code[6..10]
        }
      end

      ##
      # Expands a boolean checkbox value into a hash with "YES" or "NO" responses
      #
      # @param value [Boolean]
      # @param key [String]
      #
      # @return [Hash]
      def expand_checkbox(value, key)
        {
          "has#{key}" => value == true ? 'On' : nil,
          "no#{key}" => value == false ? 'On' : nil
        }
      end

      ##
      # Expands a checkbox value within a hash and updates it in place
      # Returns nil if the key is not present in the hash.
      # This behavior stems from VBA's requirement that boolean values
      # remain empty on the PDF if not selected on the online form.
      #
      # For more context, see this PR: https://github.com/department-of-veterans-affairs/vets-api/pull/22958
      #
      # @param hash [Hash]
      # @param key [String]
      #
      # @return [Hash]
      def expand_checkbox_in_place(hash, key)
        return nil if hash[key].nil?

        hash.merge!(expand_checkbox(hash[key], StringHelpers.capitalize_only(key)))
      end
    end
  end
end
