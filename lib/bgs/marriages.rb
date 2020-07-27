# frozen_string_literal: true

module BGS
  class Marriages
    def initialize(proc_id:, payload:, user:)
      @user = user
      @dependents = []
      @proc_id = proc_id
      @payload = payload
      @dependents_application = @payload['dependents_application']
    end

    def create
      report_marriage_history('veteran_marriage_history') if @payload['veteran_was_married_before']
      report_marriage_history('spouse_marriage_history') if @payload['spouse_was_married_before']
      add_spouse if @payload['add_spouse']
    end

    private

    def report_marriage_history(type)
      @dependents_application[type].each do |former_spouse|
        former_marriage = BGS::DependentEvents::MarriageHistory.new(former_spouse)
        marriage_info = former_marriage.format_info
        participant = bgs_service.create_participant(@proc_id)
        bgs_service.create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

        @dependents << former_marriage.serialize_dependent_result(
          participant,
          'Spouse',
          'Ex-Spouse',
          { 'type': type }
        )
      end
    end

    def add_spouse
      marriage = BGS::DependentEvents::Marriage.new(@dependents_application)
      marriage_info = marriage.format_info
      participant = bgs_service.create_participant(@proc_id)

      bgs_service.create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)
      bgs_service.generate_address(
        @proc_id,
        participant[:vnp_ptcpnt_id],
        marriage.address(marriage_info)
      )

      @dependents << marriage.serialize_dependent_result(
        participant,
        'Spouse',
        marriage_info['lives_with_vet'] ? 'Spouse' : 'Estranged Spouse',
        {
          begin_date: @dependents_application['current_marriage_information']['date'],
          marriage_state: @dependents_application['current_marriage_information']['location']['state'],
          marriage_city: @dependents_application['current_marriage_information']['location']['city'],
          type: 'spouse'
        }
      )
    end

    def bgs_service
      @bgs_service = BGS::Service.new(@user)
    end
  end
end
