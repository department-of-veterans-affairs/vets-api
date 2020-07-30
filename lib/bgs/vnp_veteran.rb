# frozen_string_literal: true

module BGS
  class VnpVeteran
    def initialize(proc_id:, payload:, user:)
      @user = user
      @proc_id = proc_id
      @payload = payload.with_indifferent_access
      @veteran_info = vnp_veteran.formatted_params(@payload)
    end

    def create
      participant = bgs_service.create_participant(@proc_id, nil)
      claim_type_end_product = bgs_service.find_benefit_claim_type_increment
      va_file_number = bgs_service.get_va_file_number
      bgs_service.create_person(person_params(participant))
      bgs_service.create_phone(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address = vet_address(participant[:vnp_ptcpnt_id])

      vnp_veteran.veteran_response(participant, va_file_number, address, claim_type_end_product)
    end

    private

    def person_params(participant)
      vnp_veteran.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
    end

    def vet_address(participant_id)
      address_params = vnp_veteran.create_address_params(@proc_id, participant_id, @veteran_info)

      bgs_service.create_address(address_params)
    end

    def vnp_veteran
      @vnp_veteran ||= BGSDependents::Veteran.new(@proc_id, @user)
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
