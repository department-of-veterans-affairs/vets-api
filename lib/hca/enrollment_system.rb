# frozen_string_literal: true
module HCA
  module EnrollmentSystem
    module_function

    FORM_TEMPLATE = {
      'form' => {
        'formIdentifier' => {
          'type' => '100',
          'value' => '1010EZ',
          'version' => 1_986_360_435
        }
      },
      'identity' => {
        'authenticationLevel' => {
          'type' => '100',
          'value' => 'anonymous'
        }
      }
    }.freeze

    def financial_flag?(veteran)
      veteran['understandsFinancialDisclosure'] || veteran['discloseFinancialInformation']
    end

    def format_address(address)
      formatted = address.slice('city', 'country')
      formatted['line1'] = address['street']

      (2..3).each do |i|
        street = address["street#{i}"]
        next if street.blank?
        formatted["line#{i}"] = street
      end

      if address['country'] == 'USA'
        formatted['state'] = address['state']
        formatted.merge!(format_zipcode(address['zipcode']))
      else
        formatted['provinceCode'] = address['state'] || address['provinceCode']
        formatted['postalCode'] = address['zipcode'] || address['postalCode']
      end

      formatted
    end

    def format_zipcode(zipcode)
      numeric_zip = zipcode.gsub(/\D/, '')
      zip_plus_4 = numeric_zip[5..8]
      zip_plus_4 = nil if !zip_plus_4.nil? && zip_plus_4.size != 4

      {
        'zipCode' => numeric_zip[0..4],
        'zipPlus4' => zip_plus_4
      }
    end

    def transform(data)
    end
  end
end
