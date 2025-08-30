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
  end
end
