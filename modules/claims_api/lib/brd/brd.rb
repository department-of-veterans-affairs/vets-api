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
    ##
    # Some values where removed from the BRD list
    #
    # 'PT' => 'Azores', # Part of Portugal
    # 'GB' => 'Great Britain'
    # '' => Great Britain and Gibraltar"  This is on the list but two distinct countries now
    # '' => "Leeward Islands" No single code, each island has thier own code
    # "" => Netherlands Antilles" Dissolved in 2010, code is no longer used
    # 'KN' => 'Nevis' Shares same code with St. Kitts
    # "" => Serbia/Montenegro" Two distinct Countries
    # 'IT' => 'Sicily', Part of Italy
    # 'YE' => 'Yemen Arab Republic' Duplicate
    ##
    COUNTRY_CODES = {
      'AF' => 'Afghanistan',
      'AL' => 'Albania',
      'DZ' => 'Algeria',
      'AO' => 'Angola',
      'AI' => 'Anguilla',
      'AG' => 'Barbuda',
      'AR' => 'Argentina',
      'AM' => 'Armenia',
      'AU' => 'Australia',
      'AT' => 'Austria',
      'AZ' => 'Azerbaijan',
      'BS' => 'Bahamas',
      'BH' => 'Bahrain',
      'BD' => 'Bangladesh',
      'BB' => 'Barbados',
      'BY' => 'Belarus',
      'BE' => 'Belgium',
      'BZ' => 'Belize',
      'BJ' => 'Benin',
      'BM' => 'Bermuda',
      'BT' => 'Bhutan',
      'BO' => 'Bolivia',
      'BA' => 'Bosnia-Herzegovina',
      'BW' => 'Botswana',
      'BR' => 'Brazil',
      'BN' => 'Brunei',
      'BG' => 'Bulgaria',
      'BF' => 'Burkina Faso',
      'MM' => 'Burma',
      'BI' => 'Burundi',
      'KH' => 'Cambodia',
      'CM' => 'Cameroon',
      'CA' => 'Canada',
      'CV' => 'Cape Verde',
      'KY' => 'Cayman Islands',
      'CF' => 'Central African Republic',
      'TD' => 'Chad',
      'CL' => 'Chile',
      'CN' => 'China',
      'CO' => 'Colombia',
      'KM' => 'Comoros',
      'CD' => "Congo, People's Republic of",
      'CR' => 'Costa Rica',
      'CI' => "Cote d'Ivoire",
      'HR' => 'Croatia',
      'CU' => 'Cuba',
      'CY' => 'Cyprus',
      'CZ' => 'Czech Republic',
      'DK' => 'Denmark',
      'DJ' => 'Djibouti',
      'DM' => 'Dominica',
      'DO' => 'Dominican Republic',
      'EC' => 'Ecuador',
      'EG' => 'Egypt',
      'SV' => 'El Salvador',
      'GQ' => 'Equatorial Guinea',
      'ER' => 'Eritrea',
      'EE' => 'Estonia',
      'ET' => 'Ethiopia',
      'FJ' => 'Fiji',
      'FI' => 'Finland',
      'FR' => 'France',
      'GF' => 'French Guiana',
      'GA' => 'Gabon',
      'GM' => 'Gambia',
      'GE' => 'Georgia',
      'DE' => 'Germany',
      'GH' => 'Ghana',
      'GI' => 'Gibraltar',
      'GR' => 'Greece',
      'GL' => 'Greenland',
      'GD' => 'Grenada',
      'GP' => 'Guadeloupe',
      'GT' => 'Guatemala',
      'GN' => 'Guinea, Republic of Guinea',
      'GW' => 'Guinea-Bissau',
      'GY' => 'Guyana',
      'HT' => 'Haiti',
      'HN' => 'Honduras',
      'HK' => 'Hong Kong',
      'HU' => 'Hungary',
      'IS' => 'Iceland',
      'IN' => 'India',
      'ID' => 'Indonesia',
      'IR' => 'Iran',
      'IQ' => 'Iraq',
      'IE' => 'Ireland',
      'IL-JM' => 'Israel (Jerusalem)',
      'IL' => 'Israel (Tel Aviv)',
      'IT' => 'Italy',
      'JM' => 'Jamaica',
      'JP' => 'Japan',
      'JO' => 'Jordan',
      'KZ' => 'Kazakhstan',
      'KE' => 'Kenya',
      'KI' => 'Kiribati',
      'XK' => 'Kosovo',
      'KW' => 'Kuwait',
      'KG' => 'Kyrgyzstan',
      'LA' => 'Laos',
      'LV' => 'Latvia',
      'LB' => 'Lebanon',
      'LS' => 'Lesotho',
      'LR' => 'Liberia',
      'LY' => 'Libya',
      'LI' => 'Liechtenstein',
      'LT' => 'Lithuania',
      'LU' => 'Luxembourg',
      'MO' => 'Macao',
      'MK' => 'Macedonia',
      'MG' => 'Madagascar',
      'MW' => 'Malawi',
      'MY' => 'Malaysia',
      'ML' => 'Mali',
      'MT' => 'Malta',
      'MQ' => 'Martinique',
      'MR' => 'Mauritania',
      'MU' => 'Mauritius',
      'MX' => 'Mexico',
      'MD' => 'Moldavia',
      'MN' => 'Mongolia',
      'ME' => 'Montenegro',
      'MS' => 'Montserrat',
      'MA' => 'Morocco',
      'MZ' => 'Mozambique',
      'NA' => 'Namibia',
      'NP' => 'Nepal',
      'NL' => 'Netherlands',
      'NC' => 'New Caledonia',
      'NZ' => 'New Zealand',
      'NI' => 'Nicaragua',
      'NE' => 'Niger',
      'NG' => 'Nigeria',
      'KP' => 'North Korea',
      'GB-NIR' => 'Northern Ireland',
      'NO' => 'Norway',
      'OM' => 'Oman',
      'PK' => 'Pakistan',
      'PA' => 'Panama',
      'PG' => 'Papua New Guinea',
      'PY' => 'Paraguay',
      'PE' => 'Peru',
      'PH' => 'Philippines (restricted payments)',
      'PL' => 'Poland',
      'PT' => 'Portugal',
      'QA' => 'Qatar',
      'YE' => 'Republic of Yemen',
      'RO' => 'Romania',
      'RU' => 'Russia',
      'RW' => 'Rwanda',
      'ST' => 'Sao-Tome/Principe',
      'SA' => 'Saudi Arabia',
      'GB-SCT' => 'Scotland',
      'SN' => 'Senegal',
      'RS' => 'Serbia',
      'SC' => 'Seychelles',
      'SL' => 'Sierra Leone',
      'SG' => 'Singapore',
      'SK' => 'Slovakia',
      'SI' => 'Slovenia',
      'SO' => 'Somalia',
      'ZA' => 'South Africa',
      'KR' => 'South Korea',
      'ES' => 'Spain',
      'LK' => 'Sri Lanka',
      'KN' => 'St. Kitts',
      'LC' => 'St. Lucia',
      'VC' => 'St. Vincent',
      'SD' => 'Sudan',
      'SR' => 'Suriname',
      'SZ' => 'Swaziland',
      'SE' => 'Sweden',
      'CH' => 'Switzerland',
      'SY' => 'Syria',
      'TW' => 'Taiwan',
      'TJ' => 'Tajikistan',
      'TZ' => 'Tanzania',
      'TH' => 'Thailand',
      'TG' => 'Togo',
      'TT' => 'Trinidad and Tobago',
      'TN' => 'Tunisia',
      'TR-01' => 'Turkey (Adana only)',
      'TR' => 'Turkey (except Adana)',
      'TM' => 'Turkmenistan',
      'US' => 'USA',
      'UG' => 'Uganda',
      'UA' => 'Ukraine',
      'AE' => 'United Arab Emirates',
      'GB' => 'United Kingdom',
      'UY' => 'Uruguay',
      'UZ' => 'Uzbekistan',
      'VU' => 'Vanuatu',
      'VE' => 'Venezuela',
      'VN' => 'Vietnam',
      'GB-WLS' => 'Wales',
      'WS' => 'Western Samoa',
      'ZM' => 'Zambia',
      'ZW' => 'Zimbabwe'
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
