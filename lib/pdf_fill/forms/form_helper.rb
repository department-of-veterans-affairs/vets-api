# frozen_string_literal: true

require 'date'

module PdfFill
  module Forms
    module FormHelper
      def split_ssn(veteran_social_security_number)
        return if veteran_social_security_number.blank?

        veteran_social_security_number = veteran_social_security_number.tr('^0-9', '')

        split_ssn = {
          'first' => veteran_social_security_number[0..2],
          'second' => veteran_social_security_number[3..4],
          'third' => veteran_social_security_number[5..8]
        }

        split_ssn
      end

      # VA file number can be up to 10 digits long; An optional leading 'c' or 'C' followed by
      # 7-9 digits. The file number field on the 4142 form has space for 9 characters so trim the
      # potential leading 'c' to ensure the file number will fit into the form without overflow.
      def extract_va_file_number(va_file_number)
        return va_file_number if va_file_number.blank? || va_file_number.length < 10
        va_file_number.sub(/^[Cc]/, '')
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
        return if country.blank?
        country[0..1]
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
    end
  end
end
