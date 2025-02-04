# frozen_string_literal: true

require 'brd/brd_response_store'
require 'library_base'

module ClaimsApi
  ##
  # Class to interact with the BRD API
  #
  # Takes an optional request parameter
  # @param [] rails request object (used to determine environment)
  class BRD < LibraryBase
    COUNTRY_CODES = {
      'Afghanistan' => 'AF',
      'Albania' => 'AL',
      'Algeria' => 'DZ',
      'Angola' => 'AO',
      'Anguilla' => 'AI',
      'Antigua' => 'AG',
      'Antigua and Barbuda' => 'AG',
      'Argentina' => 'AR',
      'Armenia' => 'AM',
      'Australia' => 'AU',
      'Austria' => 'AT',
      'Azerbaijan' => 'AZ',
      'Azores' => 'PT', # considered part of Portugal
      'Bahamas' => 'BS',
      'Bahrain' => 'BH',
      'Bangladesh' => 'BD',
      'Barbados' => 'BB',
      'Barbuda' => 'AG',
      'Belarus' => 'BY',
      'Belgium' => 'BE',
      'Belize' => 'BZ',
      'Benin' => 'BJ',
      'Bermuda' => 'BM',
      'Bhutan' => 'BT',
      'Bolivia' => 'BO',
      'Bosnia-Herzegovina' => 'BA',
      'Botswana' => 'BW',
      'Brazil' => 'BR',
      'Brunei' => 'BN',
      'Bulgaria' => 'BG',
      'Burkina Faso' => 'BF',
      'Burma' => 'MM', # Now known as Myanmar
      'Burundi' => 'BI',
      'Cambodia' => 'KH',
      'Cameroon' => 'CM',
      'Canada' => 'CA',
      'Cape Verde' => 'CV',
      'Cayman Islands' => 'KY',
      'Central African Republic' => 'CF',
      'Chad' => 'TD',
      'Chile' => 'CL',
      'China' => 'CN',
      'Colombia' => 'CO',
      'Comoros' => 'KM',
      'Congo, Democratic Republic of' => 'CD',
      "Congo, People's Republic of" => 'CD',
      'Costa Rica' => 'CR',
      "Cote d'Ivoire" => 'CI',
      'Croatia' => 'HR',
      'Cuba' => 'CU',
      'Cyprus' => 'CY',
      'Czech Republic' => 'CZ', # Czechia
      'Denmark' => 'DK',
      'Djibouti' => 'DJ',
      'Dominica' => 'DM',
      'Dominican Republic' => 'DO',
      'Ecuador' => 'EC',
      'Egypt' => 'EG',
      'El Salvador' => 'SV',
      'England' => 'GB',
      'Equatorial Guinea' => 'GQ',
      'Eritrea' => 'ER',
      'Estonia' => 'EE',
      'Ethiopia' => 'ET',
      'Fiji' => 'FJ',
      'Finland' => 'FI',
      'France' => 'FR',
      'French Guiana' => 'GF',
      'Gabon' => 'GA',
      'Gambia' => 'GM',
      'Georgia' => 'GE',
      'Germany' => 'DE',
      'Ghana' => 'GH',
      'Gibraltar' => 'GI',
      'Great Britain' => 'GB',
      # "Great Britain and Gibraltar" => "",  This is on the list but two distinct countries now
      'Greece' => 'GR',
      'Greenland' => 'GL',
      'Grenada' => 'GD',
      'Guadeloupe' => 'GP',
      'Guatemala' => 'GT',
      'Guinea' => 'GN',
      'Guinea, Republic of Guinea' => 'GN',
      'Guinea-Bissau' => 'GW',
      'Guyana' => 'GY',
      'Haiti' => 'HT',
      'Honduras' => 'HN',
      'Hong Kong' => 'HK',
      'Hungary' => 'HU',
      'Iceland' => 'IS',
      'India' => 'IN',
      'Indonesia' => 'ID',
      'Iran' => 'IR',
      'Iraq' => 'IQ',
      'Ireland' => 'IE',
      'Israel (Jerusalem)' => 'IL-JM',
      'Israel (Tel Aviv)' => 'IL',
      'Italy' => 'IT',
      'Jamaica' => 'JM',
      'Japan' => 'JP',
      'Jordan' => 'JO',
      'Kazakhstan' => 'KZ',
      'Kenya' => 'KE',
      'Kiribati' => 'KI',
      'Kosovo' => 'XK', # unoffical code, falls under ISO 3166-1 "alpha-2 user-assigned codes" - 02/2025
      'Kuwait' => 'KW',
      'Kyrgyzstan' => 'KG',
      'Laos' => 'LA',
      'Latvia' => 'LV',
      'Lebanon' => 'LB',
      # "Leeward Islands" => "", No single code, each island has thier own code
      'Lesotho' => 'LS',
      'Liberia' => 'LR',
      'Libya' => 'LY',
      'Liechtenstein' => 'LI',
      'Lithuania' => 'LT',
      'Luxembourg' => 'LU',
      'Macao' => 'MO',
      'Macedonia' => 'MK',
      'Madagascar' => 'MG',
      'Malawi' => 'MW',
      'Malaysia' => 'MY',
      'Mali' => 'ML',
      'Malta' => 'MT',
      'Martinique' => 'MQ',
      'Mauritania' => 'MR',
      'Mauritius' => 'MU',
      'Mexico' => 'MX',
      'Moldavia' => 'MD',
      'Mongolia' => 'MN',
      'Montenegro' => 'ME',
      'Montserrat' => 'MS',
      'Morocco' => 'MA',
      'Mozambique' => 'MZ',
      'Namibia' => 'NA',
      'Nepal' => 'NP',
      'Netherlands' => 'NL',
      # "Netherlands Antilles" => "", Dissolved in 2010, code is no longer used
      'Nevis' => 'KN',
      'New Caledonia' => 'NC',
      'New Zealand' => 'NZ',
      'Nicaragua' => 'NI',
      'Niger' => 'NE',
      'Nigeria' => 'NG',
      'North Korea' => 'KP',
      'Northern Ireland' => 'GB-NIR',
      'Norway' => 'NO',
      'Oman' => 'OM',
      'Pakistan' => 'PK',
      'Panama' => 'PA',
      'Papua New Guinea' => 'PG',
      'Paraguay' => 'PY',
      'Peru' => 'PE',
      'Philippines' => 'PH',
      'Philippines (restricted payments)' => 'PH',
      'Poland' => 'PL',
      'Portugal' => 'PT',
      'Qatar' => 'QA',
      'Republic of Yemen' => 'YE',
      'Romania' => 'RO',
      'Russia' => 'RU',
      'Rwanda' => 'RW',
      'Sao-Tome/Principe' => 'ST',
      'Saudi Arabia' => 'SA',
      'Scotland' => 'GB-SCT',
      'Senegal' => 'SN',
      'Serbia' => 'RS',
      # "Serbia/Montenegro" => "", Two distinct Countries
      'Seychelles' => 'SC',
      'Sicily' => 'IT', # Considered as a region within Italy
      'Sierra Leone' => 'SL',
      'Singapore' => 'SG',
      'Slovakia' => 'SK',
      'Slovenia' => 'SI',
      'Somalia' => 'SO',
      'South Africa' => 'ZA',
      'South Korea' => 'KR',
      'Spain' => 'ES',
      'Sri Lanka' => 'LK',
      'St. Kitts' => 'KN',
      'St. Lucia' => 'LC',
      'St. Vincent' => 'VC',
      'Sudan' => 'SD',
      'Suriname' => 'SR',
      'Swaziland' => 'SZ',
      'Sweden' => 'SE',
      'Switzerland' => 'CH',
      'Syria' => 'SY',
      'Taiwan' => 'TW',
      'Tajikistan' => 'TJ',
      'Tanzania' => 'TZ',
      'Thailand' => 'TH',
      'Togo' => 'TG',
      'Trinidad and Tobago' => 'TT',
      'Tunisia' => 'TN',
      'Turkey (Adana only)' => 'TR-01',
      'Turkey (except Adana)' => 'TR',
      'Turkmenistan' => 'TM',
      'USA' => 'US',
      'Uganda' => 'UG',
      'Ukraine' => 'UA',
      'United Arab Emirates' => 'AE',
      'United Kingdom' => 'GB',
      'Uruguay' => 'UY',
      'Uzbekistan' => 'UZ',
      'Vanuatu' => 'VU',
      'Venezuela' => 'VE',
      'Vietnam' => 'VN',
      'Wales' => 'GB-WLS',
      'Western Samoa' => 'WS',
      'Yemen Arab Republic' => 'YE',
      'Zambia' => 'ZM',
      'Zimbabwe' => 'ZW'
    }.freeze

    def initialize
      @response_store = BRDResponseStore
      super()
    end

    def service_name
      'BENEFITS_REFERENCE_DATA'
    end

    ##
    # List of valid countries
    #
    # @return [Array<String>] list of countries
    def countries
      response_from_cache_or_service('countries')
    rescue => e
      rescue_brd(e, 'countries')
    end

    ##
    # List of intake sites
    #
    # @return [Array<Hash>] list of intake sites
    # as {id: <number> and description: <string>}
    def intake_sites
      response_from_cache_or_service('intake-sites')
    rescue => e
      rescue_brd(e, 'intake-sites')
    end

    def disabilities
      response_from_cache_or_service('disabilities')
    rescue => e
      rescue_brd(e, 'disabilities')
    end

    def service_branches
      response_from_cache_or_service('service-branches')
    rescue => e
      rescue_brd(e, 'service-branches')
    end

    private

    def response_from_cache_or_service(brd_service)
      key = "#{service_name}:#{brd_service}"
      response = @response_store.get_brd_response(key)
      if response.nil?
        response = client.get(brd_service).body[:items]
        @response_store.set_brd_response(key, response)
      end
      response
    end

    def client
      base_name = if Settings.brd&.base_name.nil?
                    'api.va.gov/services'
                  else
                    Settings.brd.base_name
                  end

      api_key = Settings.brd&.api_key || ''
      raise StandardError, 'BRD api_key missing' if api_key.blank?

      Faraday.new("https://#{base_name}/benefits-reference-data/v1",
                  # Disable SSL for (localhost) testing
                  ssl: { verify: Settings.brd&.ssl != false },
                  headers: { 'apiKey' => api_key }) do |f|
        f.request :json
        f.response :raise_custom_error
        f.response :json, parser_options: { symbolize_names: true }
        f.adapter Faraday.default_adapter
      end
    end

    def rescue_brd(e, service)
      detail = e.respond_to?(:original_body) ? e.original_body : e
      log_outcome_for_claims_api(service, 'error', detail)

      error_handler(e)
    end
  end
end
