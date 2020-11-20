# frozen_string_literal: true

require_relative 'service'

module BGS
  class Children
    def initialize(proc_id:, payload:, user:)
      @user = user
      @children = []
      @step_children = []
      @proc_id = proc_id
      @views = payload['view:selectable686_options']
      @dependents_application = payload['dependents_application']
    end

    def create_all
      report_children if @views['add_child']
      report_stepchildren if @views['report_stepchild_not_in_household']
      report_child_event('child_marriage') if @views['report_marriage_of_child_under18']
      report_child_event('not_attending_school') if @views['report_child18_or_older_is_not_attending_school']

      {
        dependents: @children,
        step_children: @step_children
      }
    end

    private

    def report_children
      @dependents_application['children_to_add'].each do |child_info|
        child = BGSDependents::Child.new(child_info)
        formatted_info = child.format_info
        participant = bgs_service.create_participant(@proc_id)

        bgs_service.create_person(person_params(child, participant, formatted_info))
        send_address(child, participant, child.address(@dependents_application))

        @children << child.serialize_dependent_result(
          participant,
          'Child',
          formatted_info['family_relationship_type'],
          {
            marriage_termination_type_code: formatted_info['reason_marriage_ended'],
            type: 'child',
            child_prevly_married_ind: formatted_info['ever_married_ind'],
            dep_has_income_ind: formatted_info['child_income']
          }
        )
      end
    end

    def report_stepchildren
      @dependents_application['step_children'].each do |stepchild_info|
        step_child = BGSDependents::StepChild.new(stepchild_info)
        formatted_info = step_child.format_info
        participant = bgs_service.create_participant(@proc_id)
        guardian_participant = bgs_service.create_participant(@proc_id)

        step_child_guardian_person(guardian_participant, stepchild_info)
        bgs_service.create_person(person_params(step_child, participant, formatted_info))
        send_address(step_child, participant, stepchild_info['address'])

        @step_children << step_child.serialize_dependent_result(
          participant,
          'Guardian',
          'Other',
          {
            living_expenses_paid: formatted_info['living_expenses_paid'],
            guardian_particpant_id: guardian_participant[:vnp_ptcpnt_id],
            'type': 'stepchild'
          }
        )
      end
    end

    def step_child_guardian_person(guardian_participant, stepchild_info)
      bgs_service.create_person(
        {
          vnp_proc_id: @proc_id,
          vnp_ptcpnt_id: guardian_participant[:vnp_ptcpnt_id],
          first_nm: stepchild_info['who_does_the_stepchild_live_with']['first'],
          last_nm: stepchild_info['who_does_the_stepchild_live_with']['last']
        }
      )
    end

    def report_child_event(event_type)
      child_event = child_event_type(event_type)
      formatted_info = child_event.format_info
      participant = bgs_service.create_participant(@proc_id)

      bgs_service.create_person(person_params(child_event, participant, formatted_info))

      @children << child_event.serialize_dependent_result(
        participant,
        'Child',
        'Other',
        {
          'event_date': formatted_info['event_date'],
          'type': event_type
        }
      )
    end

    def person_params(calling_object, participant, dependent_info)
      calling_object.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], dependent_info)
    end

    def send_address(calling_object, participant, address_info)
      address = calling_object.generate_address(address_info)
      address_params = calling_object.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], address)

      bgs_service.create_address(address_params)
    end

    def child_event_type(event_type)
      if event_type == 'child_marriage'
        return BGSDependents::ChildMarriage.new(@dependents_application['child_marriage'])
      end

      BGSDependents::ChildStoppedAttendingSchool.new(@dependents_application['child_stopped_attending_school'])
    end

    def bgs_service
      @bgs_service ||= BGS::Service.new(@user)
    end
  end
end
