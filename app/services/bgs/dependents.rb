# frozen_string_literal: true

module BGS
  class Dependents < Base
    CHILD_STATUS =  { 'childUnder18' => 'Other', 'stepChild' => 'Stepchild', 'adopted' => 'Adopted Child', 'disabled' => 'Other', 'childOver18InSchool' => 'Other'}

    def initialize(proc_id:, veteran:, payload:, user:)
      @proc_id = proc_id
      @payload = payload
      @veteran = veteran
      @dependents = []

      super(user) # is this cool? Might be smelly. Might indicate a new class/object 🤔
    end

    def create
      add_children if @payload['childrenToAdd']
      report_deaths if @payload['deaths']

      @dependents
    end

    private

    def add_children
      @payload['childrenToAdd'].map do |child_info|
        format_child_info(child_info)

        participant = create_participant(@proc_id)
        person = create_person(@proc_id, participant[:vnp_ptcpnt_id], child_info)
        address = create_address(@proc_id, participant[:vnp_ptcpnt_id], child_info['childAddressInfo']['childAddress'])

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
        address = create_address(@proc_id, participant[:vnp_ptcpnt_id], death_info['deceasedLocationOfDeath'])

        @dependents << serialize_result(
          participant,
          person,
          address,
          death_info['participant_relationship_type'],
          death_info['family_relationship_type']
        )
      end
    end

    def serialize_result(participant, person, address, participant_relationship_type, family_relationship_type)
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
        phone_number: nil, # Doesn't exist for child
        address_line_one: address[:addrs_one_txt],
        address_line_two: address[:addrs_two_txt],
        address_line_three: address[:addrs_three_txt],
        address_state_code: address[:postal_cd],
        address_city: address[:city_nm],
        address_zip_code: address[:zip_prefix_nbr],
        email_address: nil, # Doesn't exist for child
        death_date: person[:death_dt]
      )
    end

    # We'll want to get rid of as much as possible below this after talking to FE
    def format_child_info(child_info)
      relationship_types = relationship_type(child_info)

      child_info['family_relationship_type'] = relationship_types[:family]
      child_info['participant_relationship_type'] = relationship_types[:participant]
      child_info['placeOfBirthCity'] = child_info['childPlaceOfBirth']['city']
      child_info['placeOfBirthState'] = child_info['childPlaceOfBirth']['state']
      child_info['death_date'] = nil # Doing this to get past Struct attribute

      child_info.delete('childPlaceOfBirth')
    end

    def format_death_info(death_info)
      relationship_types = relationship_type(death_info)

      death_info['family_relationship_type'] = relationship_types[:family]
      death_info['participant_relationship_type'] = relationship_types[:participant]
      death_info['first'] = death_info['fullName']['first']
      death_info['middle'] = death_info['fullName']['middle']
      death_info['last'] = death_info['fullName']['last']
      death_info['death_date'] = death_info['deceasedDateOfDeath']

      death_info.delete('fullName')
    end

    def relationship_type(info)
      fmly_rel_type = ''
      ptcpnt_rel_type = ''

      if info['dependentType']
        fmly_rel_type = info['dependentType'].capitalize.gsub('_', ' ')
        ptcpnt_rel_type = info['dependentType'].capitalize.gsub('_', ' ')

        if info['dependentType'] == 'DEPENDENT_PARENT'
          ptcpnt_rel_type = 'Guardian'
          fmly_rel_type = 'Other'
        end
      end

      if info['childStatus']
        child_status = info['childStatus'].key(true)
        fmly_rel_type = CHILD_STATUS[child_status]
      end

      {
        family: fmly_rel_type,
        participant: ptcpnt_rel_type
      }
    end
  end
end