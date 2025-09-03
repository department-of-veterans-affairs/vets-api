# frozen_string_literal: true

module ClaimsApi
  module PdfMapperBase
    def concatenate_address(address_line_one, address_line_two, address_line_three)
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

    def regex_date_conversion(date)
      if date.present?
        date_match = date.match(/^(?:(?<year>\d{4})(?:-(?<month>\d{2}))?(?:-(?<day>\d{2}))*|(?<month>\d{2})?(?:-(?<day>\d{2}))?-?(?<year>\d{4}))$/) # rubocop:disable Layout/LineLength
        date_match&.values_at(:year, :month, :day)
      end
    end
  end
end
