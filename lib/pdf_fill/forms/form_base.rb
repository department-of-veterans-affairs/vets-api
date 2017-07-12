# frozen_string_literal: true
module PdfFill
  module Forms
    class FormBase
      def self.date_strftime
        '%m/%d/%Y'
      end

      def initialize(form_data)
        @form_data = form_data.deep_dup
      end

      def combine_name_addr_extras(hash, name_key, address_key)
        [hash[name_key], combine_full_address_extras(hash[address_key])].compact.join("\n")
      end

      def combine_name_addr(hash, address_key: 'address', name_key: 'name', combined_key: 'nameAndAddr')
        return if hash.try(:[], address_key).blank?
        extras_address = combine_name_addr_extras(hash, name_key, address_key)

        hash[address_key] = combine_full_address(hash[address_key])
        address = combine_hash(hash, [name_key, address_key], ', ')

        hash[combined_key] = PdfFill::FormValue.new(address, extras_address)
      end

      def combine_previous_names(previous_names)
        return if previous_names.blank?

        previous_names.map do |previous_name|
          combine_full_name(previous_name)
        end.join(', ')
      end

      def combine_full_address_extras(address)
        return if address.blank?

        [
          address['street'],
          address['street2'],
          [address['city'], address['state'], address['postalCode']].compact.join(', '),
          address['country']
        ].compact.join("\n")
      end

      def combine_full_address(address)
        combine_hash(
          address,
          %w(
            street
            street2
            city
            state
            postalCode
            country
          ),
          ', '
        )
      end

      def combine_full_name(full_name)
        combine_hash(full_name, %w(first middle last suffix))
      end

      def expand_checkbox(value, key)
        {
          "has#{key}" => value == true,
          "no#{key}" => value == false
        }
      end

      def combine_hash(hash, keys, separator = ' ')
        return if hash.blank?

        combined = []

        keys.each do |key|
          combined << hash[key]
        end

        combined.compact.join(separator)
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
