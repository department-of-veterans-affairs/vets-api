# frozen_string_literal: true

module BGS
  class Dependents
    def initialize(proc_id:, payload:, user:)
      @proc_id = proc_id
      @payload = payload
      @dependents = []
      @dependents_application = @payload['dependents_application']
      @user = user
      @views = payload['view:selectable686_options']
    end

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/CyclomaticComplexity
    def create
      report_674 if @views['report674']
      add_children if @views['add_child']
      report_deaths if @views['report_death']
      report_divorce if @dependents_application['report_divorce']
      report_stepchild if @views['report_stepchild_not_in_household']
      report_child_event('child_marriage') if @views['report_marriage_of_child_under18']
      report_child_event('not_attending_school') if @views['report_child18_or_older_is_not_attending_school']

      @dependents
    end

    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    private

    def add_children
      @dependents_application['children_to_add'].each do |child_info|
        child = BGSDependents::Child.new(child_info)
        formatted_info = child.format_info
        participant = bgs_service.create_participant(@proc_id)

        bgs_service.create_person(person_params(child, participant, formatted_info))
        send_address(child, participant, child.address(@dependents_application))

        @dependents << child.serialize_dependent_result(
          participant,
          'Child',
          formatted_info['family_relationship_type'],
          {
            marriage_termination_type_code: formatted_info['reason_marriage_ended'],
            type: 'child',
            child_prevly_married_ind: formatted_info['ever_married_ind']
          }
        )
      end
    end

    def report_deaths
      @dependents_application['deaths'].each do |death_info|
        death = BGSDependents::Death.new(death_info)
        relationship_types = death.relationship_type(death_info)

        next if relationship_types[:family] == 'Child' # BGS does not support child death at this time

        formatted_info = death.format_info
        death_info['location']['state_code'] = death_info['location'].delete('state')
        participant = bgs_service.create_participant(@proc_id)
        bgs_service.create_person(person_params(death, participant, formatted_info))
        # Need to add death location once BGS adds support for this functionality

        @dependents << death.serialize_dependent_result(
          participant,
          relationship_types[:participant],
          relationship_types[:family],
          { type: 'death' }
        )
      end
    end

    def report_divorce
      divorce = BGSDependents::Divorce.new(@dependents_application['report_divorce'])
      formatted_info = divorce.format_info
      participant = bgs_service.create_participant(@proc_id)
      bgs_service.create_person(person_params(divorce, participant, formatted_info))

      @dependents << divorce.serialize_dependent_result(
        participant,
        'Spouse',
        'Spouse',
        {
          divorce_state: formatted_info['divorce_state'],
          divorce_city: formatted_info['divorce_city'],
          divorce_country: formatted_info['divorce_country'],
          end_date: formatted_info['end_date'],
          marriage_termination_type_code: formatted_info['marriage_termination_type_code'],
          type: 'divorce'
        }
      )
    end

    def report_stepchild
      @dependents_application['step_children'].each do |stepchild_info|
        step_child = BGSDependents::StepChild.new(stepchild_info)
        formatted_info = step_child.format_info
        participant = bgs_service.create_participant(@proc_id)
        bgs_service.create_person(person_params(step_child, participant, formatted_info))
        send_address(step_child, participant, stepchild_info['address'])

        @dependents << step_child.serialize_dependent_result(
          participant,
          'Child',
          'Stepchild',
          {
            living_expenses_paid: formatted_info['living_expenses_paid'],
            'type': 'stepchild'
          }
        )
      end
    end

    def report_child_event(event_type)
      child_event = child_event_type(event_type)
      formatted_info = child_event.format_info
      participant = bgs_service.create_participant(@proc_id)

      bgs_service.create_person(person_params(child_event, participant, formatted_info))

      @dependents << child_event.serialize_dependent_result(
        participant,
        'Child',
        'Other',
        {
          'event_date': formatted_info['event_date'],
          'type': event_type
        }
      )
    end

    def report_674
      adult_attending_school = BGSDependents::AdultChildAttendingSchool.new(
        @dependents_application
      )
      formatted_info = adult_attending_school.format_info
      participant = bgs_service.create_participant(@proc_id)
      bgs_service.create_person(person_params(adult_attending_school, participant, formatted_info))
      send_address(adult_attending_school, participant, adult_attending_school.address)

      @dependents << adult_attending_school.serialize_dependent_result(
        participant,
        'Child',
        'Other',
        { 'type': '674' }
      )
    end

    def child_event_type(event_type)
      if event_type == 'child_marriage'
        return BGSDependents::ChildMarriage.new(@dependents_application['child_marriage'])
      end

      BGSDependents::ChildStoppedAttendingSchool.new(@dependents_application['child_stopped_attending_school'])
    end

    def person_params(calling_object, participant, dependent_info)
      calling_object.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], dependent_info)
    end

    def send_address(calling_object, participant, address_info)
      address = calling_object.generate_address(address_info)
      address_params = calling_object.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], address)

      bgs_service.create_address(address_params)
    end

    def bgs_service
      @bgs_service ||= BGS::Service.new(@user)
    end
  end
end
