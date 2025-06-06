# frozen_string_literal: true

require 'pdf_fill/form_value'

module PdfFill
  module Forms
    class FormBase
      attr_reader :form_data

      START_PAGE = 1
      SECTIONS = nil
      QUESTION_KEY = nil
      DEFAULT_LABEL_WIDTH = nil

      def self.date_strftime
        '%m/%d/%Y'
      end

      def initialize(form_data)
        @form_data = form_data.deep_dup
      end

      def combine_name_addr_extras(hash, name_key, address_key)
        [combine_full_address_extras(hash[address_key])].compact.join("\n")
      end

      def combine_name_addr(hash, address_key: 'address', name_key: 'name', combined_key: 'nameAndAddr')
        return if hash.try(:[], address_key).blank?

        extras_address = combine_name_addr_extras(hash, name_key, address_key)

        hash['combinedAddr'] = if hash[address_key]['postalCode'].is_a?(Hash)
                                 address_dup = hash[address_key].deep_dup
                                 address_dup['postalCode'] = combine_postal_code(address_dup['postalCode'])
                                 combine_full_address(address_dup)
                               else
                                 combine_full_address(hash[address_key])
                               end

        address = combine_hash(hash, [name_key, 'combinedAddr'], ', ')
        hash.delete('combinedAddr')

        hash[combined_key] = PdfFill::FormValue.new(address, extras_address)
      end

      def combine_both_addr(hash, key)
        original_addr = hash[key]
        return if original_addr.blank?

        extras_address = combine_full_address_extras(original_addr)
        address = combine_full_address(original_addr)

        hash[key] = PdfFill::FormValue.new(address, extras_address)
      end

      def combine_previous_names(previous_names)
        return if previous_names.blank?

        previous_names.map do |previous_name|
          combine_full_name(previous_name)
        end.join(', ')
      end

      def combine_full_address_extras(address)
        return if address.blank?

        postal_code = address['postalCode']
        postal_code = combine_postal_code(postal_code) if postal_code.is_a?(Hash)

        [
          address['street'],
          address['street2'],
          [address['city'], address['state'], postal_code].compact.join(', '),
          address['country']
        ].compact.join("\n")
      end

      def combine_postal_code(postal_code)
        code = postal_code.deep_dup
        combined_postal_code = code['firstFive'].to_s
        combined_postal_code << "-#{code['lastFour']}" unless code['lastFour'].nil?
        combined_postal_code
      end

      def combine_full_address(address)
        combine_hash(
          address,
          %w[
            street
            street2
            street3
            city
            state
            postalCode
            country
          ],
          ', '
        )
      end

      def expand_signature(full_name, signature_date = Time.zone.today)
        signature = combine_hash(full_name, %w[first last])
        @form_data['signature'] = signature
        @form_data['signatureDate'] = signature_date.to_s if signature.present?
      end

      def combine_full_name(full_name)
        combine_hash(full_name, %w[first middle last suffix])
      end

      def expand_checkbox(value, key)
        {
          "has#{key}" => value == true,
          "no#{key}" => value == false
        }
      end

      def combine_hash(hash, keys, separator = ' ')
        return if hash.blank?

        keys
          .map { |key| hash[key] }
          .compact_blank # removes both nil and empty strings
          .join(separator)
      end

      def expand_date_range(hash, key)
        return if hash.blank?

        date_range = hash[key]
        return if date_range.blank?

        hash["#{key}Start"] = date_range['from']
        hash["#{key}End"] = date_range['to']
        hash.delete(key)

        hash
      end
    end
  end
end
