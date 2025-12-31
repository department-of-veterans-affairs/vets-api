# frozen_string_literal: true

require 'date'
# rubocop:disable Metrics/ModuleLength
module PdfFill
  module Forms
    module FormHelper
      def split_ssn(veteran_social_security_number)
        return if veteran_social_security_number.blank?

        {
          'first' => veteran_social_security_number[0..2],
          'second' => veteran_social_security_number[3..4],
          'third' => veteran_social_security_number[5..8]
        }
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

        country = address['country'] || address['country_name']
        return if country.blank?

        case country.size
        when 3
          # 3-character code (ISO 3166-1 alpha-3), convert to 2-character (alpha-2)
          IsoCountryCodes.find(country).alpha2
        when 2
          # Already a 2-character code (ISO 3166-1 alpha-2), return as-is
          country
        else
          # Country name or other format, search by name
          IsoCountryCodes.search_by_name(country)[0].alpha2
        end
      rescue IsoCountryCodes::UnknownCodeError
        country
      end

      def split_postal_code(address)
        return if address.blank?

        postal_code = address['postalCode'] || address['zip_code'] || address['postal_code']

        return if postal_code.blank?

        postal_code = postal_code.tr('\-', '')

        split_postal_code = postal_code.scan(/.{1,5}/)
        if split_postal_code.length == 2
          {
            'firstFive' => split_postal_code.first,
            'lastFour' => split_postal_code.last
          }
        else
          {
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
        {
          'month' => s_date[1],
          'day' => s_date.last,
          'year' => s_date.first
        }
      end

      def combine_date_ranges(date_range_array)
        return if date_range_array.nil?

        date_range_array.map { |r| "from: #{r['from']} to: #{r['to']}" if r }.join("\n")
      end

      def address_block(address)
        return if address.nil?

        [
          [address['street'], address['street2']].compact.join(' '),
          [address['city'], address['state'], address['postalCode']].compact.join(' '),
          address['country']
        ].compact.join("\n")
      end

      def expand_checkbox_as_hash(hash, key)
        value = hash.try(:[], key)

        return if value.blank?

        hash['checkbox'] = {
          value => true
        }
      end

      def select_radio_button(value)
        value ? 0 : 'Off'
      end

      def select_checkbox(value)
        value ? 1 : 'Off'
      end

      def format_boolean(bool_attribute)
        return '' if bool_attribute.nil?

        bool_attribute ? 'Yes' : 'No'
      end

      def format_radio_yes_no(value)
        return '' if value.nil?

        case value
        when 'Y'
          'Yes'
        when 'N'
          'No'
        else
          # Value can sometimes be 'NA'
          value
        end
      end

      def split_currency_string(decimal_string)
        return if decimal_string.blank?

        dollars, cents = decimal_string.split('.')
        dollars ||= ''
        reverse_dollars = dollars.reverse.scan(/\d{1,3}/)

        {
          thousands: reverse_dollars[1]&.reverse&.rjust(3),
          ones: reverse_dollars[0]&.reverse&.rjust(3),
          cents: cents || '00'
        }
      end

      def domestic?(country)
        country.in?(%w[USA US])
      end

      def normalize_mailing_address(address)
        # Not necessary to include country if domestic
        if domestic?(address['country'])
          address.delete('country')
        else
          address['country'] = extract_country(address)
        end
        # Format Mexican state names
        address['state'] = address['state'].gsub('-', ' ').titleize if address['country'].in?(%w[MX])
      end

      # Further readability improvements require various refactoring and code
      # de-duplication across different forms.
      module PhoneNumberFormatting
        def expand_phone_number(phone_number)
          phone_number = phone_number.delete('^0-9')
          {
            'phone_area_code' => phone_number[0..2],
            'phone_first_three_numbers' => phone_number[3..5],
            'phone_last_four_numbers' => phone_number[6..9]
          }
        end

        def format_us_phone(number)
          expand_phone_number(number).values.join('-')
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
