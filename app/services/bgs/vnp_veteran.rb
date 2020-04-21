# frozen_string_literal: true
require_relative 'value_objects/vnp_person_address_phone'

module BGS
  class VnpVeteran < Base
    def initialize(proc_id:, payload:, user:)
      @proc_id = proc_id
      @veteran_info = formatted_params(payload)

      super(user) # is this cool? Might be smelly. Might indicate a new class/object 🤔
    end

    def create
      participant = create_participant(@proc_id)
      person = create_person(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      phone = create_phone(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address = create_address(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)

      ::ValueObjects::VnpPersonAddressPhone.new(
        vnp_proc_id: @proc_id,
        vnp_participant_id: participant[:vnp_ptcpnt_id],
        vnp_participant_address_id: address[:vnp_ptcpnt_addrs_id],
        participant_relationship_type_name: 'Veteran',
        family_relationship_type_name: 'Veteran',
        first_name: person[:first_nm],
        middle_name: person[:first_nm],
        last_name: person[:last_nm],
        suffix_name: person[:suffix_nm],
        birth_date: person[:brthdy_dt],
        birth_state_code: person[:birth_state_cd],
        birth_city_name: person[:birth_city_nm],
        file_number: person[:file_nbr],
        ssn_number: person[:ssn_nbr],
        phone_number: phone[:phone_nbr],
        address_line_one: address[:addrs_one_txt],
        address_line_two: address[:addrs_two_txt],
        address_line_three: address[:addrs_three_txt],
        address_state_code: address[:postal_cd],
        address_city: address[:city_nm],
        address_zip_code: address[:zip_prefix_nbr],
        email_address: address[:email_addrs_txt],
        death_date: nil, # Setting to nil to satisfy struct
        begin_date: nil, # Setting to nil to satisfy struct
        end_date: nil, # Setting to nil to satisfy struct
        ever_married_indicator: nil, # Setting to nil to satisfy struct
        marriage_state: nil, # Setting to nil to satisfy struct
        marriage_city: nil, # Setting to nil to satisfy struct
        divorce_state: nil, # Setting to nil to satisfy struct
        divorce_city: nil, # Setting to nil to satisfy struct
        marriage_termination_type_cd: nil # Setting to nil to satisfy struct
      )
    end

    private

    def formatted_params(payload)
      [
        *payload['veteran_information'],
        *payload['more_veteran_information'],
        *payload['veteran_address']
      ].to_h
    end
  end
end