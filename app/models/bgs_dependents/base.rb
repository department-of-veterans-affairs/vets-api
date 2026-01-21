# frozen_string_literal: true

require 'vets/model'

module BGSDependents
  class Base
    include Vets::Model
    MILITARY_POST_OFFICE_TYPE_CODES = %w[APO DPO FPO].freeze

    # Gets the person's address based on the lives with veteran flag
    #
    # @param dependents_application [Hash] the submitted form information
    # @param lives_with_vet [Boolean] does live with veteran indicator
    # @param alt_address [Hash] alternate address
    # @return [Hash] address information
    #
    def dependent_address(dependents_application:, lives_with_vet:, alt_address:)
      return dependents_application.dig('veteran_contact_information', 'veteran_address') if lives_with_vet

      alt_address
    end

    def relationship_type(info)
      if info['dependent_type']
        return { participant: 'Guardian', family: 'Other' } if info['dependent_type'] == 'DEPENDENT_PARENT'

        {
          participant: info['dependent_type'].capitalize.gsub('_', ' '),
          family: info['dependent_type'].capitalize.gsub('_', ' ')
        }
      end
    end

    def serialize_dependent_result(
      participant,
      participant_relationship_type,
      family_relationship_type,
      optional_fields = {}
    )
      {
        vnp_participant_id: participant[:vnp_ptcpnt_id],
        participant_relationship_type_name: participant_relationship_type,
        family_relationship_type_name: family_relationship_type,
        begin_date: optional_fields[:begin_date],
        end_date: optional_fields[:end_date],
        event_date: optional_fields[:event_date],
        marriage_state: optional_fields[:marriage_state],
        marriage_city: optional_fields[:marriage_city],
        marriage_country: optional_fields[:marriage_country],
        divorce_state: optional_fields[:divorce_state],
        divorce_city: optional_fields[:divorce_city],
        divorce_country: optional_fields[:divorce_country],
        marriage_termination_type_code: optional_fields[:marriage_termination_type_code],
        living_expenses_paid_amount: optional_fields[:living_expenses_paid],
        child_prevly_married_ind: optional_fields[:child_prevly_married_ind],
        guardian_particpant_id: optional_fields[:guardian_particpant_id],
        type: optional_fields[:type],
        dep_has_income_ind: optional_fields[:dep_has_income_ind]
      }
    end

    def create_person_params(proc_id, participant_id, payload)
      {
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: participant_id,
        first_nm: payload['first'],
        middle_nm: payload['middle'],
        last_nm: payload['last'],
        suffix_nm: payload['suffix'],
        brthdy_dt: format_date(payload['birth_date']),
        birth_cntry_nm: payload['place_of_birth_country'],
        birth_state_cd: payload['place_of_birth_state'],
        birth_city_nm: payload['place_of_birth_city'],
        file_nbr: payload['va_file_number'],
        ssn_nbr: payload['ssn'],
        death_dt: format_date(payload['death_date']),
        ever_maried_ind: payload['ever_married_ind'],
        vet_ind: payload['vet_ind'],
        martl_status_type_cd: payload['martl_status_type_cd'],
        vnp_srusly_dsabld_ind: payload['not_self_sufficient']
      }
    end

    # Converts a string "00/00/0000" to standard iso8601 format
    #
    # @return [String] formatted date
    #
    def format_date(date)
      return nil if date.nil?

      DateTime.parse("#{date} 12:00:00").to_time.iso8601
    end

    def generate_address(address)
      return if address.blank?

      # BGS will throw an error if we pass in a military postal code in for state
      if MILITARY_POST_OFFICE_TYPE_CODES.include?(address['city'])
        address['military_postal_code'] = address.delete('state')
        address['military_post_office_type_code'] = address.delete('city')
      end

      adjust_address_lines_for!(address: address['veteran_address']) if address['veteran_address']

      adjust_address_lines_for!(address:)
      adjust_country_name_for!(address:)

      address
    end

    # BGS will not accept address lines longer than 20 characters
    def adjust_address_lines_for!(address:)
      return if address.blank?

      all_lines = "#{address['street']} #{address['street2']} #{address['street3']}"
      new_lines = all_lines.gsub(/\s+/, ' ').scan(/.{1,19}(?: |$)/).map(&:strip)

      address['address_line1'] = new_lines[0]
      address['address_line2'] = new_lines[1]
      address['address_line3'] = new_lines[2]
    end

    # rubocop:disable Metrics/MethodLength
    # This method converts ISO 3166-1 Alpha-3 country codes to ISO 3166-1 country names.
    def adjust_country_name_for!(address:)
      return if address.blank?

      return if address['country'] == 'USA'

      country_name = address['country']
      return if country_name.blank? || country_name.size != 3

      # The ISO 3166-1 country name for GBR exceeds BIS's (formerly, BGS) 50 char limit. No other country name exceeds
      # this limit. For GBR, BIS expects "United Kingdom" instead. BIS has suggested using one of their web services
      # to get the correct country names, rather than relying on the IsoCountryCodes gem below. It may be worth
      # pursuing that some day. Until then, the following short-term improvement suffices.

      # we are now using a short term fix for special country names that are different from IsoCountryCodes in BIS.
      special_country_names = { 'USA' => 'USA', 'BOL' => 'Bolivia', 'BIH' => 'Bosnia-Herzegovina', 'BRN' => 'Brunei',
                                'CPV' => 'Cape Verde', 'COG' => "Congo, People's Republic of",
                                'COD' => 'Congo, Democratic Republic of', 'CIV' => "Cote d'Ivoire",
                                'CZE' => 'Czech Republic', 'PRK' => 'North Korea', 'KOR' => 'South Korea',
                                'LAO' => 'Laos', 'MKD' => 'Macedonia', 'MDA' => 'Moldavia', 'RUS' => 'Russia',
                                'KNA' => 'St. Kitts', 'LCA' => 'St. Lucia', 'STP' => 'Sao-Tome/Principe',
                                'SCG' => 'Serbia', 'SYR' => 'Syria', 'TZA' => 'Tanzania',
                                'GBR' => 'United Kingdom', 'VEN' => 'Venezuela', 'VNM' => 'Vietnam',
                                'YEM' => 'Yemen Arab Republic' }
      address['country'] =
        if country_name.to_s == 'TUR'
          address['city'].to_s.downcase == 'adana' ? 'Turkey (Adana only)' : 'Turkey (except Adana)'
        elsif special_country_names[country_name.to_s].present?
          special_country_names[country_name.to_s]
        else
          IsoCountryCodes.find(country_name).name
        end

      address
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def create_address_params(proc_id, participant_id, payload)
      address = generate_address(payload)
      if address['military_postal_code'].present? || address['country'] == 'USA'
        frgn_postal_code = nil
        state = address['state']
        zip_prefix_nbr = address['postal_code']
      else
        frgn_postal_code = address['postal_code']
        state = nil
        zip_prefix_nbr = nil
      end
      {
        efctv_dt: Time.current.iso8601,
        vnp_ptcpnt_id: participant_id,
        vnp_proc_id: proc_id,
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        addrs_one_txt: address['address_line1'],
        addrs_two_txt: address['address_line2'],
        addrs_three_txt: address['address_line3'],
        city_nm: address['city'],
        cntry_nm: address['country'],
        postal_cd: state,
        frgn_postal_cd: frgn_postal_code,
        mlty_postal_type_cd: address['military_postal_code'],
        mlty_post_office_type_cd: address['military_post_office_type_code'],
        zip_prefix_nbr:,
        prvnc_nm: address['state'],
        email_addrs_txt: payload['email_address']
      }
    end
    # rubocop:enable Metrics/MethodLength

    def formatted_boolean(bool_attribute)
      return nil if bool_attribute.nil?

      bool_attribute ? 'Y' : 'N'
    end
  end
end
