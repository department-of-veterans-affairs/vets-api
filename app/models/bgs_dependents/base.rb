# frozen_string_literal: true

module BGSDependents
  class Base < Common::Base
    def dependent_address(dependents_application, lives_with_vet, alt_address)
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
        divorce_state: optional_fields[:divorce_state],
        divorce_city: optional_fields[:divorce_city],
        marriage_termination_type_code: optional_fields[:marriage_termination_type_code],
        living_expenses_paid_amount: optional_fields[:living_expenses_paid],
        type: optional_fields[:type]
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
        birth_state_cd: payload['place_of_birth_state'],
        birth_city_nm: payload['place_of_birth_city'],
        file_nbr: payload['va_file_number'],
        ssn_nbr: payload['ssn'],
        death_dt: format_date(payload['death_date']),
        ever_maried_ind: payload['ever_married_ind'],
        vet_ind: payload['vet_ind'],
        martl_status_type_cd: 'Married'
      }
    end

    def format_date(date)
      return nil if date.nil?

      Date.parse(date).to_time.iso8601
    end

    def generate_address(address)
      if address['view:lives_on_military_base'] == true
        address['military_postal_code'] = address.delete('state_code')
        address['military_post_office_type_code'] = address.delete('city')
      end

      address
    end

    def create_address_params(proc_id, participant_id, payload)
      {
        efctv_dt: Time.current.iso8601,
        vnp_ptcpnt_id: participant_id,
        vnp_proc_id: proc_id,
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        addrs_one_txt: payload['address_line1'],
        addrs_two_txt: payload['address_line2'],
        addrs_three_txt: payload['address_line3'],
        city_nm: payload['city'],
        cntry_nm: payload['country_name'],
        postal_cd: payload['state_code'],
        mlty_postal_type_cd: payload['military_postal_code'],
        mlty_post_office_type_cd: payload['military_post_office_type_code'],
        zip_prefix_nbr: payload['zip_code'],
        prvnc_nm: payload['state_code'],
        email_addrs_txt: payload['email_address']
      }
    end
  end
end
