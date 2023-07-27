# frozen_string_literal: true

module AppealsApi
  class Appellant
    def initialize(auth_headers:, form_data:, type:)
      @type = type
      @auth_headers = auth_headers || {}
      @form_data = form_data || {}
    end

    def first_name
      find_datum("X-VA#{header_prefix}-First-Name", 'firstName')
    end

    def middle_initial
      find_datum("X-VA#{header_prefix}-Middle-Initial", 'middleInitial')
    end

    def last_name
      find_datum("X-VA#{header_prefix}-Last-Name", 'lastName')
    end

    def icn
      find_datum('X-VA-ICN', 'icn')
    end

    def ssn
      find_datum("X-VA#{header_prefix}-SSN", 'ssn')
    end

    def birth_date_string
      find_datum("X-VA#{header_prefix}-Birth-Date", 'birthDate')
    end

    def file_number
      find_datum('X-VA-File-Number', 'fileNumber')
    end

    def service_number
      find_datum('X-VA-Service-Number', 'serviceNumber')
    end

    def insurance_policy_number
      find_datum('X-VA-Insurance-Policy-Number', 'insurancePolicyNumber')
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

    # NOTE: Decision Reviews v2 uses auth_headers for a few form fields and form_data for the rest, while the segmented
    # APIs use form_data for all the fields (no auth_headers) - this attempts to find a field's data in either place
    def find_datum(header_name, *form_data_path)
      auth_headers&.dig(header_name) || form_data&.dig(*form_data_path)
    end

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
      form_data.dig('data', 'attributes', 'claimant', 'lastName').present? ||
        auth_headers.include?('X-VA-NonVeteranClaimant-Last-Name')
    end

    def mpi_veteran
      ClaimsApi::Veteran.new(
        uuid: ssn,
        ssn:,
        first_name:,
        last_name:,
        va_profile: ClaimsApi::Veteran.build_profile(birth_date),
        loa: { current: 3, highest: 3 }
      )
    end
  end
end
