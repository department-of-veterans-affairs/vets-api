# frozen_string_literal: true

module BGS
  class VnpVeteran < Service
    def initialize(proc_id:, payload:, user:)
      @proc_id = proc_id
      @payload = payload.with_indifferent_access
      @veteran_info = formatted_params(@payload, user)

      super(user)
    end

    def create
      participant = create_participant(@proc_id, nil)
      claim_type_end_product = find_benefit_claim_type_increment
      va_file_number = get_va_file_number
      person = create_person(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      create_phone(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address = create_address(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)

      serialize_result(participant, person, va_file_number, address, claim_type_end_product)
    end

    private

    def get_va_file_number
      with_multiple_attempts_enabled do
        person = service.people.find_person_by_ptcpnt_id(@user[:participant_id])

        person[:file_nbr]
      end
    end

    def find_benefit_claim_type_increment
      with_multiple_attempts_enabled do
        service.data.find_benefit_claim_type_increment(
          {
            ptcpnt_id: @user[:participant_id],
            bnft_claim_type_cd: '130DPNEBNADJ',
            pgm_type_cd: 'CPL',
            ssn: @user[:ssn] # Just here to make the mocks work
          }
        )
      end
    end

    def serialize_result(participant, person, va_file_number, address, end_product)
      {
        vnp_participant_id: participant[:vnp_ptcpnt_id],
        first_name: person[:first_nm],
        last_name: person[:last_nm],
        vnp_participant_address_id: address[:vnp_ptcpnt_addrs_id],
        file_number: va_file_number,
        address_line_one: address[:addrs_one_txt],
        address_line_two: address[:addrs_two_txt],
        address_line_three: address[:addrs_three_txt],
        address_country: address[:cntry_nm],
        address_state_code: address[:postal_cd],
        address_city: address[:city_nm],
        address_zip_code: address[:zip_prefix_nbr],
        type: 'veteran',
        benefit_claim_type_end_product: end_product
      }
    end

    def formatted_params(payload, user)
      dependents_application = payload['dependents_application']
      vet_info = [
        *payload['veteran_information'],
        ['first', user[:first_name]],
        ['middle', user[:middle_name]],
        ['last', user[:last_name]],
        *dependents_application.dig('veteran_contact_information'),
        *dependents_application.dig('veteran_contact_information', 'veteran_address'),
        %w[vet_ind Y]
      ]

      if dependents_application['current_marriage_information']
        vet_info << ['martl_status_type_cd', dependents_application['current_marriage_information']['type']]
      end

      vet_info.to_h
    end
  end
end
