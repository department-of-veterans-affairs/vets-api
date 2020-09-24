# frozen_string_literal: true

require_relative 'service'

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

    def create_all
      report_674 if @views['report674']
      report_deaths if @views['report_death']
      report_divorce if @dependents_application['report_divorce']

      @dependents
    end

    private

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
