# frozen_string_literal: true

module AppealsApi
  class NonVeteranClaimant
    def initialize(auth_headers:, form_data:)
      @auth_headers = auth_headers || {}
      @form_data = form_data || {}
    end

    def first_name
      auth_headers['X-VA-Claimant-First-Name']
    end

    def middle_initial
      auth_headers['X-VA-Claimant-Middle-Initial']
    end

    def last_name
      auth_headers['X-VA-Claimant-Last-Name']
    end

    def ssn
      auth_headers['X-VA-Claimant-SSN']
    end

    def birth_date_string
      auth_headers['X-VA-Claimant-Birth-Date']
    end

    def birth_month
      birth_date&.strftime('%m')
    end

    def birth_day
      birth_date&.strftime('%d')
    end

    def birth_year
      birth_date&.strftime('%Y')
    end

    def full_name
      "#{first_name} #{middle_initial} #{last_name}".squeeze(' ').strip
    end

    def number_and_street
      address_combined
    end

    def city
      address['city']
    end

    def state_code
      address['stateCode']
    end

    def country_code
      address['countryCodeISO2']
    end

    def zip_code_5
      address['zipCode5']
    end

    def international_postal_code
      address['internationalPostalCode']
    end

    def zip_code
      international_postal_code || zip_code_5
    end

    def email
      form_data['email'].to_s.strip
    end

    def phone_data
      form_data['phone']
    end

    def phone_formatted
      AppealsApi::HigherLevelReview::Phone.new phone_data
    end

    def phone_string
      phone_formatted.to_s
    end

    def area_code
      phone_data&.dig('areaCode')
    end

    def phone_prefix
      phone_data&.dig('phoneNumber')&.first(3)
    end

    def phone_line_number
      phone_data&.dig('phoneNumber')&.last(4)
    end

    def phone_ext
      return unless domestic_phone?

      ext = phone_data&.dig('phoneNumberExt')

      "x#{ext}" if ext.present?
    end

    def international_number
      return if domestic_phone?

      phone_string
    end

    def phone_country_code
      phone_data&.dig('countryCode')
    end

    def ssn_first_three
      ssn&.first(3)
    end

    def ssn_second_two
      ssn&.slice(3..4)
    end

    def ssn_last_four
      ssn&.last(4)
    end

    private

    attr_accessor :auth_headers, :form_data

    def birth_date
      return if birth_date_string.blank?

      @birth_date ||= Date.parse(birth_date_string)
    end

    def address_combined
      return if address.blank?

      @address_combined ||=
        [address['addressLine1'],
         address['addressLine2'],
         address['addressLine3']].compact.map(&:strip).join(' ')
    end

    def domestic_phone?
      phone_country_code == '1'
    end

    def address
      form_data['address'].presence || {}
    end
  end
end
