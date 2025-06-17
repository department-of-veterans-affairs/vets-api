# frozen_string_literal: true

require_relative 'service'

module BGS
  class Marriages
    def initialize(proc_id:, payload:, user:)
      @user = user
      @dependents = []
      @proc_id = proc_id
      @payload = payload
      @dependents_application = @payload['dependents_application']
    end

    def create_all
      report_marriage_history('veteran_marriage_history') if @payload['veteran_was_married_before']
      report_marriage_history('spouse_marriage_history') if @payload['spouse_was_married_before']
      add_spouse if @payload['view:selectable686_options']['add_spouse']

      @dependents
    end

    private

    def report_marriage_history(type)
      @dependents_application[type].each do |former_spouse|
        former_marriage = BGSDependents::MarriageHistory.new(former_spouse)
        marriage_info = former_marriage.format_info
        participant = bgs_service.create_participant(@proc_id)

        create_person(former_marriage, participant, marriage_info)

        @dependents << former_marriage.serialize_dependent_result(
          participant,
          'Spouse',
          'Ex-Spouse',
          spouse_dependent_optional_fields(type, marriage_info)
        )
      end
    end

    def spouse_dependent_optional_fields(type, marriage_info)
      {
        type:,
        begin_date: marriage_info['start_date'],
        marriage_country: marriage_info['marriage_country'],
        marriage_state: marriage_info['marriage_state'],
        marriage_city: marriage_info['marriage_city'],
        divorce_state: marriage_info['divorce_state'],
        divorce_city: marriage_info['divorce_city'],
        divorce_country: marriage_info['divorce_country'],
        end_date: marriage_info['end_date'],
        marriage_termination_type_code: marriage_info['marriage_termination_type_code']
      }
    end

    def add_spouse
      spouse = BGSDependents::Spouse.new(@dependents_application)
      spouse_info = spouse.format_info
      participant = bgs_service.create_participant(@proc_id)

      create_person(spouse, participant, spouse_info)
      send_address(spouse, participant, spouse_info)

      @dependents << spouse.serialize_dependent_result(
        participant,
        'Spouse',
        live_with_vet? ? 'Spouse' : 'Estranged Spouse',
        {
          begin_date: @dependents_application['current_marriage_information']['date'],
          marriage_country: @dependents_application['current_marriage_information']['location']['country'],
          marriage_state: @dependents_application['current_marriage_information']['location']['state'],
          marriage_city: @dependents_application['current_marriage_information']['location']['city'],
          type: 'spouse',
          dep_has_income_ind: spouse_info['spouse_income']
        }
      )
    end

    def create_person(calling_object, participant, marriage_info)
      params = calling_object.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

      bgs_service.create_person(params)
    end

    def send_address(calling_object, participant, address_info)
      address = calling_object.generate_address(address_info)
      address_params = calling_object.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], address)

      bgs_service.create_address(address_params)
    end

    def bgs_service
      @bgs_service = BGS::Service.new(@user)
    end

    def live_with_vet?
      @dependents_application['does_live_with_spouse']['spouse_does_live_with_veteran']
    end
  end
end
