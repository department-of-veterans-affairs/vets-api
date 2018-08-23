# frozen_string_literal: true

module PdfFill
  module Forms
    class FormHelper
      def self.split_ssn(veteran_social_security_number)
        return if veteran_social_security_number.blank?

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
      def self.extract_va_file_number(va_file_number)
        return va_file_number if va_file_number.blank? || va_file_number.length < 10
        va_file_number.sub(/^[Cc]/, '')
      end

      def self.extract_middle_i(hash, key)
        full_name = hash[key]
        return if full_name.blank?

        middle_name = full_name['middle']

        if middle_name.blank? || middle_name.nil?
          return hash[key]
        else
          full_name['middleInitial'] = middle_name[0]
        end
        hash[key]
      end

      def self.extract_country(address)
        return if address.blank?
        country = address['country']
        return if country.blank?
        country[0..1]
      end

      def self.split_postal_code(address)
        return if address.blank?
        postal_code = address['postalCode']

        return if postal_code.blank?

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

      def self.split_date(date)
        return if date.blank?
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
