# frozen_string_literal: true

require_relative 'service'

module BGS
  class VnpVeteran
    def initialize(proc_id:, payload:, user:)
      @user = user
      @proc_id = proc_id
      @payload = payload.with_indifferent_access
      @veteran_info = veteran.formatted_params(@payload)
    end

    def create
      participant = bgs_service.create_participant(@proc_id, @user.participant_id)
      claim_type_end_product = bgs_service.find_benefit_claim_type_increment
      va_file_number = @payload['veteran_information']['va_file_number']
      person_params = veteran.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address_params = veteran.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address = bgs_service.create_address(address_params)
      bgs_service.create_person(person_params)
      bgs_service.create_phone(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      veteran.veteran_response(participant, va_file_number, address, claim_type_end_product)
    end

    private

    def veteran
      @veteran ||= BGSDependents::Veteran.new(@proc_id, @user)
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
