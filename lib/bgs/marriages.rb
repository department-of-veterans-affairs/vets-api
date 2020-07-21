# frozen_string_literal: true

module BGS
  class Marriages < Service
    include Helpers::Formatters

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
      add_spouse if @payload['add_spouse']
    end

    private

    def report_marriage_history(type)
      @dependents_application[type].each do |former_spouse|
        marriage_info = format_former_marriage_info(former_spouse)
        participant = create_participant(@proc_id)
        create_person(@proc_id, participant[:vnp_ptcpnt_id], marriage_info)

        @dependents << serialize_dependent_result(
          participant,
          'Spouse',
          'Ex-Spouse',
          { 'type': type }
        )
      end
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

      @dependents << serialize_dependent_result(
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
  end
end
