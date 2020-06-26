# frozen_string_literal: true

module BGS
  class Dependents < Base
    CHILD_STATUS = {'child_under18' => 'Other', 'step_child' => 'Stepchild', 'biological' => 'Biological', 'adopted' => 'Adopted Child', 'disabled' => 'Other', 'child_over18_in_school' => 'Other'}

    def initialize(proc_id:, payload:, user:)
      @proc_id = proc_id
      @payload = payload
      @dependents = []
      @dependents_application = payload['dependents_application']

      super(user) # is this cool? Might be smelly. Might indicate a new class/object 🤔
    end

    def create
      # add_children if @dependents_application.dig("view:selectable686_options", "add_child")
      # report_deaths if @payload['report_death']
      # add_spouse if @dependents_application.dig('view:selectable686_options', 'add_spouse')
      # # report_divorce if @payload['report_divorce']
      # report_stepchild if @payload['report_stepchild_not_in_household']
      # report_child_marriage if @payload['report_marriage_of_child_under18']
      # report_child18_or_older_is_not_attending_school if @payload['report_child18_or_older_is_not_attending_school']
      report_674 if @dependents_application.dig("view:selectable686_options", "report674")
      # report_veteran_marriage_history if @payload['veteran_marriage_history']
      # report_spouse_marriage_history if @payload['spouse_marriage_history']

      @dependents
    end

    private

    def add_children
      @dependents_application['children_to_add'].each do |child_info|
        format_child_info(child_info)
        child_address = child_info["does_child_live_with_you"] == true ? @dependents_application['veteran_contact_information']['veteran_address'] : child_info['child_address_info']['address']
        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], child_info)
        generate_address(participant[:vnp_ptcpnt_id], child_address)

        @dependents << serialize_result(
          participant,
          child_info['participant_relationship_type'],
          child_info['family_relationship_type'],
          {
            marriage_termination_type_code: child_info['reason_marriage_ended'],
            type: 'child'
          }
        )
      end
    end

    def report_deaths
      @dependents_application['deaths'].each do |death_info|
        formatted_death_info = format_death_info(death_info)
        death_info['location']['state_code'] = death_info['location'].delete('state')

        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], formatted_death_info)
        # I think we need the death_location instead of creating an address
        # There is no support in the API for death location
        # create_address(@proc_id, participant[:vnp_ptcpnt_id], death_info['location'])

        @dependents << serialize_result(
          participant,
          formatted_death_info['participant_relationship_type'],
          formatted_death_info['family_relationship_type'],
          {type: 'death'}
        )
      end
    end

    def add_spouse
      marriage_info = format_marriage_info

      family_relationship_type = @dependents_application.dig('does_live_with_spouse', 'spouse_does_live_with_veteran') == true ? 'Spouse' : 'Estranged Spouse'

      spouse_address = family_relationship_type == 'Spouse' ? @dependents_application['veteran_contact_information']['veteran_address'] : @dependents_application['does_live_with_spouse']['address']
      participant = create_participant(@proc_id)
      create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

      generate_address(participant[:vnp_ptcpnt_id], spouse_address)

      @dependents << serialize_result(
        participant,
        'Spouse',
        family_relationship_type,
        {
          begin_date: @dependents_application['current_marriage_information']['date'],
          marriage_state: @dependents_application['current_marriage_information']['location']['state'],
          marriage_city: @dependents_application['current_marriage_information']['location']['city'],
          type: 'spouse'
        }
      )
    end

    def report_divorce
      divorce_info = format_divorce_info
      participant = create_participant(@proc_id)
      create_person(@proc_id, participant[:vnp_ptcpnt_id], divorce_info)

      @dependents << serialize_result(
        participant,
        'Spouse',
        'Spouse',
        {
          divorce_state: divorce_info['divorce_state'],
          divorce_city: divorce_info['divorce_city'],
          marriage_termination_type_cd: divorce_info['marriage_termination_type_code']
        }
      )
    end

    def report_stepchild
      @dependents_application['step_children'].each do |stepchild_info|
        # not using this at the moment, don't know what to do with it: "who_does_the_stepchild_live_with"=>{"first"=>"Adam", "middle"=>"Steven", "last"=>"Huberws"}
        step_child_formatted = format_stepchild_info(stepchild_info)
        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], step_child_formatted)
        generate_address(participant[:vnp_ptcpnt_id], stepchild_info['address'])

        @dependents << serialize_result(
          participant,
          step_child_formatted['participant_relationship_type'],
          step_child_formatted['family_relationship_type'],
          {
            living_expenses_paid: step_child_formatted['living_expenses_paid'],
            'type': 'stepchild'
          }
        )
      end
    end

    def report_child_marriage
      # What do we do about family relationship type? We don't ask the question on the form
      child_marriage_info = format_child_marriage_info
      participant = create_participant(@proc_id)
      create_person(@proc_id, participant[:vnp_ptcpnt_id], child_marriage_info)

      @dependents << serialize_result(
        participant,
        'Child',
        'Other',
        {
          'event_date': child_marriage_info['event_date'],
          'type': 'child_marriage'
        }
      )
    end

    def report_child18_or_older_is_not_attending_school
      # What do we do about family relationship type? We don't ask the question on the form
      child_not_attending_school_info = format_child_not_attending_school_info
      participant = create_participant(@proc_id)
      create_person(@proc_id, participant[:vnp_ptcpnt_id], child_not_attending_school_info)

      @dependents << serialize_result(
        participant,
        'Child',
        'Other',
        {
          'event_date': child_not_attending_school_info['event_date'],
          'type': 'not_attending_school'
        }
      )
    end

    def report_674
      formatted_674_info = format_674_info
      student_address = @dependents_application['student_address_marriage_tuition']['address']
      participant = create_participant(@proc_id)
      create_person(@proc_id, participant[:vnp_ptcpnt_id], formatted_674_info)
      generate_address(participant[:vnp_ptcpnt_id], student_address)

      @dependents << serialize_result(
        participant,
        'Child',
        'Other',
        {
          'type': '674'
        }
      )
    end

    def generate_address(participant_id, address)
      if address['view:lives_on_military_base'] == true
        address['military_postal_code'] = address.delete('state_code')
        address['military_post_office_type_code'] = address.delete('city')

        create_address(@proc_id, participant_id, address)
      else
        create_address(@proc_id, participant_id, address)
      end
    end

    def report_veteran_marriage_history
      @dependents_application['veteran_marriage_history'].each do |former_spouse|
        marriage_info = format_former_marriage_info(former_spouse)
        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

        @dependents << serialize_result(
          participant,
          'Spouse',
          'Ex-Spouse',
          {
            'type': 'veteran_former_marriage'
          }
        )
      end
    end

    def report_spouse_marriage_history
      @dependents_application['spouse_marriage_history'].each do |former_spouse|
        marriage_info = format_former_marriage_info(former_spouse)
        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

        @dependents << serialize_result(
          participant,
          'Spouse',
          'Ex-Spouse',
          {
            'type': 'spouse_former_marriage'
          }
        )
      end
    end

    def format_former_marriage_info(former_spouse_payload)
      [
        *former_spouse_payload.dig('full_name'),
        ['start_date', former_spouse_payload['start_date']],
        ['end_date', former_spouse_payload['end_date']],
        ['marriage_state', former_spouse_payload.dig('start_location', 'state')],
        ['marriage_city', former_spouse_payload.dig('start_location', 'city')],
        ['divorce_state', former_spouse_payload.dig('start_location', 'state')],
        ['divorce_city', former_spouse_payload.dig('start_location', 'city')],
        ['marriage_termination_type_code', former_spouse_payload['reason_marriage_ended_other']]
      ].to_h
    end

    def format_674_info
      name_and_ssn = @dependents_application['student_name_and_ssn']
      marriage_tuition = @dependents_application['student_address_marriage_tuition']

      [
        *name_and_ssn['full_name'],
        ['ssn', name_and_ssn['ssn']],
        ['birth_date', name_and_ssn['birth_date']],
        ['ever_married_ind', marriage_tuition['was_married'] == true ? 'Y' : 'N']
      ].to_h
    end

    def format_child_not_attending_school_info
      [
        *@dependents_application['child_stopped_attending_school']['full_name'],
        ['event_date', @dependents_application['child_stopped_attending_school']['date_child_left_school']]
      ].to_h
    end

    def format_child_marriage_info
      [
        *@dependents_application['child_marriage']['full_name'],
        ['event_date', @dependents_application['child_marriage']['date_married']]
      ].to_h
    end

    def format_stepchild_info(stepchild_info)
      [
        *stepchild_info['full_name'],
        ['living_expenses_paid', stepchild_info['living_expenses_paid']],
        ['participant_relationship_type', 'Child'],
        ['family_relationship_type', 'Stepchild'],
        ['lives_with_relatd_person_ind', 'N']
      ].to_h
    end

    def format_child_info(child_info)
      child_status = child_info['child_status'].key(true)
      child_name = [
        *child_info.dig('full_name')
      ].to_h

      child_info.merge!(child_name)
      child_info['participant_relationship_type'] = 'Child'
      child_info['family_relationship_type'] = CHILD_STATUS[child_status]
      child_info['place_of_birth_state'] = child_info['place_of_birth']['state']
      child_info['place_of_birth_city'] = child_info['place_of_birth']['city']
      child_info['death_date'] = nil # Doing this to get past Struct attribute
      child_info['reason_marriage_ended'] = child_info.dig('previous_marriage_details', 'reason_marriage_ended')
      child_info['ever_married_ind'] = child_info['previously_married'] == 'Yes' ? 'Y' : 'N'
    end

    def format_death_info(death_info)
      relationship_types = relationship_type(death_info)
      [
        *death_info.dig('full_name'),
        ['family_relationship_type', relationship_types[:family]],
        ['participant_relationship_type', relationship_types[:participant]],
        ['death_date', death_info['date']],
        ['vet_ind', 'N']
      ].to_h
    end

    def format_marriage_info
      spouse_information = @dependents_application['spouse_information']
      lives_with_veteran = @dependents_application['does_live_with_spouse']['spouse_does_live_with_veteran']

      marriage_info = spouse_information['full_name']
      marriage_info['ssn'] = spouse_information['ssn']
      marriage_info['birth_date'] = spouse_information['birth_date']
      marriage_info['ever_married_ind'] = 'Y'
      marriage_info['martl_status_type_cd'] = lives_with_veteran ? 'Married' : 'Separated'
      marriage_info['vet_ind'] = 'N'

      if spouse_information['is_veteran'] == true
        marriage_info['vet_ind'] = 'Y'
        marriage_info['va_file_number'] = spouse_information['va_file_number']
        # marriage_info['service_number'] = spouse_information['service_number'] not sure where this is supposed to go
      end

      marriage_info
    end

    def format_divorce_info
      report_divorce_info = @payload['report_divorce']['former_spouse_name']
      report_divorce_info['divorce_state'] = @payload['report_divorce']['location_of_divorce']['state']
      report_divorce_info['divorce_city'] = @payload['report_divorce']['location_of_divorce']['city']
      report_divorce_info['marriage_termination_type_code'] = @payload['report_divorce']['explanation_of_annullment_or_void']
      report_divorce_info['event_dt'] = @payload['report_divorce']['date_of_divorce']
      report_divorce_info['vet_ind'] = 'N'
      report_divorce_info['type'] = 'divorce'

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

      {
        family: fmly_rel_type,
        participant: ptcpnt_rel_type
      }
    end

    def serialize_result(
      participant,
      participant_relationship_type,
      family_relationship_type,
      optional_fields = {}
    )

      {
        vnp_participant_id: participant[:vnp_ptcpnt_id], # Both
        participant_relationship_type_name: participant_relationship_type, # dependent only
        family_relationship_type_name: family_relationship_type, # dependent only
        begin_date: optional_fields[:begin_date], # dependent only
        end_date: optional_fields[:end_date], # dependent only
        event_date: optional_fields[:event_date], # dependent only
        marriage_state: optional_fields[:marriage_state], # dependent only
        marriage_city: optional_fields[:marriage_city], # dependent only
        divorce_state: optional_fields[:divorce_state], # dependent only
        divorce_city: optional_fields[:divorce_city], # dependent only
        marriage_termination_type_code: optional_fields[:marriage_termination_type_code], # dependent only
        living_expenses_paid_amount: optional_fields[:living_expenses_paid], # dependent only
        type: optional_fields[:type] # both
      }
    end
  end
end