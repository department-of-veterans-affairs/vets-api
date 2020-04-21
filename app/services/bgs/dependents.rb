# frozen_string_literal: true

module BGS
  class Dependents < Base
    CHILD_STATUS = {'child_under18' => 'Other', 'step_child' => 'Stepchild', 'adopted' => 'Adopted Child', 'disabled' => 'Other', 'child_over18_in_school' => 'Other'}

    def initialize(proc_id:, veteran:, payload:, user:)
      @proc_id = proc_id
      @payload = payload
      @veteran = veteran
      @dependents = []

      super(user) # is this cool? Might be smelly. Might indicate a new class/object 🤔
    end

    def create
      add_children if @payload['children_to_add']
      report_deaths if @payload['deaths']
      add_spouse if @payload['spouse_information']
      report_divorce if @payload['report_divorce']

      @dependents
    end

    private

    def add_children
      @payload['children_to_add'].each do |child_info|
        format_child_info(child_info)

        participant = create_participant(@proc_id)
        person = create_person(@proc_id, participant[:vnp_ptcpnt_id], child_info)
        address = create_address(@proc_id, participant[:vnp_ptcpnt_id], child_info['child_address_info']['child_address'])
        @dependents << serialize_result(
          participant,
          person,
          address,
          'Child',
          child_info['family_relationship_type']
        )
      end
    end

    def report_deaths
      @payload['deaths'].map do |death_info|
        format_death_info(death_info)

        participant = create_participant(@proc_id)
        person = create_person(@proc_id, participant[:vnp_ptcpnt_id], death_info)
        address = create_address(@proc_id, participant[:vnp_ptcpnt_id], death_info['deceased_location_of_death'])

        @dependents << serialize_result(
          participant,
          person,
          address,
          death_info['participant_relationship_type'],
          death_info['family_relationship_type']
        )
      end
    end

    def add_spouse
      marriage_info = format_marriage_info

      participant = create_participant(@proc_id)
      person = create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)
      address = create_address(@proc_id, participant[:vnp_ptcpnt_id], @payload['current_spouse_address'])

      @dependents << serialize_result(
        participant,
        person,
        address,
        'Spouse',
        'Spouse',
        {
          begin_date: @payload['current_marriage_details']['date_of_marriage'],
          marriage_state: @payload['current_marriage_details']['location_of_marriage']['state'],
          marriage_city: @payload['current_marriage_details']['location_of_marriage']['city']
        }
      )
    end

    def report_divorce
      divorce_info = format_divorce_info

      participant = create_participant(@proc_id)
      person = create_person(@proc_id, participant[:vnp_ptcpnt_id], divorce_info)
      address = create_address(@proc_id, participant[:vnp_ptcpnt_id], @payload['report_divorce']['location_of_divorce'])

      @dependents << serialize_result(
        participant,
        person,
        address,
        'Spouse',
        'Spouse',
        {
          divorce_state: divorce_info['divorce_state'],
          divorce_city: divorce_info['divorce_city'],
          marriage_termination_type_cd: divorce_info['marriage_termination_type_cd']
        }
      )
    end

    # TODO: maybe turn optional stuff into a hash
    def serialize_result(
      participant,
      person,
      address,
      participant_relationship_type,
      family_relationship_type,
      optional_fields = {}
    )

      ::ValueObjects::VnpPersonAddressPhone.new(
        vnp_proc_id: @proc_id,
        vnp_participant_id: participant[:vnp_ptcpnt_id],
        vnp_participant_address_id: address[:vnp_ptcpnt_addrs_id],
        participant_relationship_type_name: participant_relationship_type,
        family_relationship_type_name: family_relationship_type,
        first_name: person[:first_nm],
        middle_name: person[:middle_nm],
        last_name: person[:last_nm],
        suffix_name: person[:suffix_nm],
        birth_date: person[:brthdy_dt],
        birth_state_code: person[:birth_state_cd],
        birth_city_name: person[:birth_city_nm],
        file_number: person[:file_nbr],
        ssn_number: person[:ssn_nbr],
        address_line_one: address[:addrs_one_txt],
        address_line_two: address[:addrs_two_txt],
        address_line_three: address[:addrs_three_txt],
        address_state_code: address[:postal_cd],
        address_city: address[:city_nm],
        address_zip_code: address[:zip_prefix_nbr],
        death_date: person[:death_dt],
        ever_married_indicator: person[:ever_maried_ind],
        phone_number: optional_fields[:phone_number],
        email_address: optional_fields[:email_address],
        begin_date: optional_fields[:begin_date],
        end_date: optional_fields[:end_date],
        marriage_state: optional_fields[:marriage_state],
        marriage_city: optional_fields[:marriage_city],
        divorce_state: optional_fields[:divorce_state],
        divorce_city: optional_fields[:divorce_city],
        marriage_termination_type_cd: optional_fields[:marriage_termination_type_cd]
      )
    end

    # We'll want to get rid of as much as possible below this after talking to FE
    def format_child_info(child_info)
      relationship_types = relationship_type(child_info)

      child_info['family_relationship_type'] = relationship_types[:family]
      child_info['participant_relationship_type'] = relationship_types[:participant]
      child_info['place_of_birth_city'] = child_info['child_place_of_birth']['city']
      child_info['place_of_birth_state'] = child_info['child_place_of_birth']['state']
      child_info['death_date'] = nil # Doing this to get past Struct attribute
    end

    def format_death_info(death_info)
      relationship_types = relationship_type(death_info)

      death_info['family_relationship_type'] = relationship_types[:family]
      death_info['participant_relationship_type'] = relationship_types[:participant]
      death_info['first'] = death_info['full_name']['first']
      death_info['middle'] = death_info['full_name']['middle']
      death_info['last'] = death_info['full_name']['last']
      death_info['death_date'] = death_info['deceased_date_of_death']
      death_info['vet_ind'] = 'N'
    end

    def format_marriage_info
      marriage_info = @payload['spouse_information']['spouse_full_name']
      marriage_info['ssn'] = @payload['spouse_information']['spouse_ssn']
      marriage_info['brthdy_dt'] = @payload['spouse_information']['spouse_dob']
      marriage_info['ever_maried_ind'] = 'Y'
      marriage_info['vet_ind'] = 'N'

      if @payload['spouse_information']['is_spouse_veteran'] == true
        marriage_info['vet_ind'] = 'Y'
        marriage_info['va_file_number'] = @payload['spouse_information']['spouse_va_file_number']
        marriage_info['service_number'] = @payload['spouse_information']['spouse_service_number']
      end

      marriage_info
    end

    def format_divorce_info
      report_divorce_info = @payload['report_divorce']['former_spouse_name']
      report_divorce_info['divorce_state'] = @payload['report_divorce']['location_of_divorce']['state']
      report_divorce_info['divorce_city'] = @payload['report_divorce']['location_of_divorce']['city']
      report_divorce_info['marriage_termination_type_cd'] = @payload['report_divorce']['explanation_of_annullment_or_void']
      report_divorce_info['vet_ind'] = 'N'

      report_divorce_info
    end

    def relationship_type(info)
      fmly_rel_type = ''
      ptcpnt_rel_type = ''

      if info['dependent_type']
        fmly_rel_type = info['dependent_type'].capitalize.gsub('_', ' ')
        ptcpnt_rel_type = info['dependent_type'].capitalize.gsub('_', ' ')

        if info['dependent_type'] == 'DEPENDENT_PARENT'
          ptcpnt_rel_type = 'Guardian'
          fmly_rel_type = 'Other'
        end
      end

      if info['child_status']
        child_status = info['child_status'].key(true)
        fmly_rel_type = CHILD_STATUS[child_status]
      end

      {
        family: fmly_rel_type,
        participant: ptcpnt_rel_type
      }
    end
  end
end