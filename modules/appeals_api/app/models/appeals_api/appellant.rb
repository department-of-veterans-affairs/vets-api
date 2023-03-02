# frozen_string_literal: true

module AppealsApi
  class Appellant
    def initialize(auth_headers:, form_data:, type:)
      @type = type
      @auth_headers = auth_headers || {}
      @form_data = form_data || {}
    end

    def first_name
      auth_headers["X-VA#{header_prefix}-First-Name"]
    end

    def middle_initial
      auth_headers["X-VA#{header_prefix}-Middle-Initial"]
    end

    def last_name
      auth_headers["X-VA#{header_prefix}-Last-Name"]
    end

    def ssn
      auth_headers["X-VA#{header_prefix}-SSN"]
    end

    def birth_date_string
      auth_headers["X-VA#{header_prefix}-Birth-Date"]
    end

    def file_number
      auth_headers['X-VA-File-Number']
    end

    def service_number
      auth_headers['X-VA-Service-Number']
    end

    def insurance_policy_number
      auth_headers['X-VA-Insurance-Policy-Number']
    end

    def birth_date
      return if birth_date_string.blank?

      @birth_date ||= Date.parse(birth_date_string)
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

    def homeless?
      form_data['homeless']
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

    def phone_country_code
      phone_data&.dig('countryCode')
    end

    def timezone
      form_data&.dig('timezone').presence&.strip
    end

    def signing_appellant?
      # claimant is signer if present
      return true if claimant? && claimant_headers_present?

      veteran? && !claimant_headers_present?
    end

    def veteran?
      type == :veteran
    end

    def claimant?
      type == :claimant
    end

    def domestic_phone?
      phone_country_code.blank? || phone_country_code == '1'
    end

    private

    attr_accessor :auth_headers, :form_data, :type

    def header_prefix
      @header_prefix ||= veteran? ? '' : '-NonVeteranClaimant'
    end

    def address_combined
      return if address.blank?

      @address_combined ||=
        [address['addressLine1'],
         address['addressLine2'],
         address['addressLine3']].compact.map(&:strip).join(' ')
    end

    def address
      # empty hash when claimant appellant but no address provided
      form_data['address'] || {}
    end

    def claimant_headers_present?
      auth_headers.include?('X-VA-NonVeteranClaimant-Last-Name')
    end

    def mpi_veteran
      ClaimsApi::Veteran.new(
        uuid: ssn,
        ssn: ssn,
        first_name: first_name,
        last_name: last_name,
        va_profile: ClaimsApi::Veteran.build_profile(birth_date),
        loa: { current: 3, highest: 3 }
      )
    end
  end
end
