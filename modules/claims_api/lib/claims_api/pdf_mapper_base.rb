# frozen_string_literal: true

module ClaimsApi
  module PdfMapperBase
    def concatenate_address(address_line_one, address_line_two, address_line_three = nil)
      [address_line_one, address_line_two, address_line_three]
        .compact
        .map(&:strip)
        .reject(&:empty?)
        .join(' ')
    end

    def concatenate_zip_code(nested_address_object)
      zip_first_five = nested_address_object&.dig('zipFirstFive') || ''
      zip_last_four = nested_address_object&.dig('zipLastFour') || ''
      international_zip = nested_address_object&.dig('internationalPostalCode')
      if zip_last_four.present?
        "#{zip_first_five}-#{zip_last_four}"
      elsif international_zip.present?
        international_zip
      else
        zip_first_five
      end
    end

    def format_ssn(ssn)
      "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
    end

    def format_birth_date(birth_date_data)
      {
        month: birth_date_data[5..6].to_s,
        day: birth_date_data[8..9].to_s,
        year: birth_date_data[0..3].to_s
      }
    end

    def make_date_string_month_first(date, date_length)
      year, month, day = regex_date_conversion(date)
      return if year.nil? || date_length.nil?

      if date_length == 4
        year.to_s
      elsif date_length == 7
        "#{month}/#{year}"
      else
        "#{month}/#{day}/#{year}"
      end
    end

    def make_date_object(date, date_length)
      year, month, day = regex_date_conversion(date)
      return if year.nil? || date_length.nil?

      if date_length == 4
        { year: }
      elsif date_length == 7
        { month:, year: }
      else
        { year:, month:, day: }

      end
    end

    def regex_date_conversion(date)
      if date.present?
        date_match = date.match(/^(?:(?<year>\d{4})(?:-(?<month>\d{2}))?(?:-(?<day>\d{2}))*|(?<month>\d{2})?(?:-(?<day>\d{2}))?-?(?<year>\d{4}))$/) # rubocop:disable Layout/LineLength
        date_match&.values_at(:year, :month, :day)
      end
    end

    def format_country(country)
      country == 'USA' ? 'US' : country
    end

    def convert_phone(phone)
      phone&.gsub!(/[^0-9]/, '')
      return nil if phone.nil? || (phone.length < 10)

      return "#{phone[0..2]}-#{phone[3..5]}-#{phone[6..9]}" if phone.length == 10

      "#{phone[0..1]}-#{phone[2..3]}-#{phone[4..7]}-#{phone[8..11]}" if phone.length > 10
    end
  end
end
