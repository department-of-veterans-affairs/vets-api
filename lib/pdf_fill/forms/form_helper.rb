# frozen_string_literal: true

require 'date'

module PdfFill
  module Forms
    module FormHelper
      def split_ssn(veteran_social_security_number)
        return if veteran_social_security_number.blank?

        split_ssn = {
          'first' => veteran_social_security_number[0..2],
          'second' => veteran_social_security_number[3..4],
          'third' => veteran_social_security_number[5..8]
        }

        split_ssn
      end

      def extract_middle_i(hash, key)
        full_name = hash[key]
        return if full_name.blank?
        middle_name = full_name['middle']
        full_name['middleInitial'] = middle_name[0] if middle_name.present?
        full_name
      end

      def extract_country(address)
        return if address.blank?
        country = address['country']
        IsoCountryCodes.find(country).alpha2
      end

      def split_postal_code(address)
        return if address.blank?
        postal_code = address['postalCode']

        return if postal_code.blank?

        postal_code = postal_code.tr('^0-9', '')

        split_postal_code = postal_code.scan(/.{1,5}/)
        if split_postal_code.length == 2
          return {
            'firstFive' => split_postal_code.first,
            'lastFour' => split_postal_code.last
          }
        else
          return {
            'firstFive' => split_postal_code.first,
            'lastFour' => ''
          }
        end
      end

      def validate_date(date)
        return if date.blank?
        format_ok = date.match(/\d{4}-\d{2}-\d{2}/)

        begin
          parseable = Date.strptime(date, '%Y-%m-%d')
        rescue ArgumentError
          false
        end

        format_ok && parseable
      end

      def split_date(date)
        return unless validate_date(date)
        s_date = date.split('-')
        split_date = {
          'month' => s_date[1],
          'day' => s_date.last,
          'year' => s_date.first
        }
        split_date
      end

      def combine_date_ranges(date_range_array)
        return if date_range_array.nil?
        extras_ranges = []

        date_range_array.map do |range|
          extras_ranges.push('from: ' + range['from'] + ' to: ' + range['to']) if range
        end
        extras_ranges.join("\n")
      end
    end
  end
end
