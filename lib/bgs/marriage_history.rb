# frozen_string_literal: true

module BGS
  class Marriages < Service
    def initialize(proc_id:, payload:, user:)
      @proc_id = proc_id
      @payload = payload
      @dependents = []
      @dependents_application = @payload['dependents_application']

      super(user)
    end

    def create
      report_marriage_history('veteran_marriage_history') if @payload['veteran_was_married_before']
      report_marriage_history('spouse_marriage_history') if @payload['spouse_was_married_before']
      report_child_marriage if @payload['report_marriage_of_child_under18']
      add_spouse if @payload['add_spouse']
    end

    private

    def report_marriage_history(type)
      @dependents_application[type].each do |former_spouse|
        marriage_info = format_former_marriage_info(former_spouse)
        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

        @dependents << serialize_result(
          participant,
          'Spouse',
          'Ex-Spouse',
          {'type': type}
        )
      end
    end

    def format_marriage_info(spouse_information, lives_with_vet)
      marriage_info = {
        'ssn': spouse_information['ssn'],
        'birth_date': spouse_information['birth_date'],
        'ever_married_ind': 'Y',
        'martl_status_type_cd': lives_with_vet ? 'Married' : 'Separated',
        'vet_ind': spouse_information['is_veteran'] ? 'Y' : 'N'
      }.merge(spouse_information['full_name']).with_indifferent_access

      if spouse_information['is_veteran']
        marriage_info.merge!({'va_file_number': spouse_information['va_file_number']})
      end

      marriage_info
    end

    def add_spouse
      lives_with_vet = @dependents_application.dig('does_live_with_spouse', 'spouse_does_live_with_veteran')
      marriage_info = format_marriage_info(@dependents_application['spouse_information'], lives_with_vet)
      participant = create_participant(@proc_id)

      create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)
      generate_address(
        participant[:vnp_ptcpnt_id],
        dependent_address(lives_with_vet, @dependents_application.dig('does_live_with_spouse', 'address'))
      )

      @dependents << serialize_result(
        participant,
        'Spouse',
        lives_with_vet ? 'Spouse' : 'Estranged Spouse',
        {
          begin_date: @dependents_application['current_marriage_information']['date'],
          marriage_state: @dependents_application['current_marriage_information']['location']['state'],
          marriage_city: @dependents_application['current_marriage_information']['location']['city'],
          type: 'spouse'
        }
      )
    end

    def format_former_marriage_info(former_spouse)
      {
        'start_date': former_spouse['start_date'],
        'end_date': former_spouse['end_date'],
        'marriage_state': former_spouse.dig('start_location', 'state'),
        'marriage_city': former_spouse.dig('start_location', 'city'),
        'divorce_state': former_spouse.dig('start_location', 'state'),
        'divorce_city': former_spouse.dig('start_location', 'city'),
        'marriage_termination_type_code': former_spouse['reason_marriage_ended_other']
      }.merge(former_spouse['full_name']).with_indifferent_access
    end

    def report_child_marriage
      # What do we do about family relationship type? We don't ask the question on the form
      child_marriage_info = format_child_marriage_info(@dependents_application['child_marriage'])
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

    def format_child_marriage_info(child_marriage)
      {
        'event_date': child_marriage['date_married']
      }.merge(child_marriage['full_name']).with_indifferent_access
    end

    def serialize_result(
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
  end
end
