# frozen_string_literal: true

require_relative 'service'

module BGS
  class VnpVeteran
    def initialize(proc_id:, payload:, user:, claim_type:)
      @user = user
      @proc_id = proc_id
      @payload = payload.with_indifferent_access
      @veteran_info = veteran.formatted_params(@payload)
      @claim_type = claim_type
    end

    def create
      participant = bgs_service.create_participant(@proc_id, @user.participant_id)
      claim_type_end_product = bgs_service.find_benefit_claim_type_increment(@claim_type)
      va_file_number = @payload['veteran_information']['va_file_number']
      person_params = veteran.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address_params = veteran.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address = bgs_service.create_address(address_params)
      location_id = get_location_id(address[:zip_prefix_nbr], address[:cntry_nm], '')
      bgs_service.create_person(person_params)
      bgs_service.create_phone(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      veteran.veteran_response(participant, va_file_number, address, claim_type_end_product, location_id)
    end

    private

    def get_location_id(zip, country, province)
      # find the regional office number closest to the Veteran's zip code
      regional_office_number = bgs_service.get_regional_office_by_zip_code(
        zip, country, province, 'CP', @user.ssn
      )
      # retrieve the list of all regional offices
      # match the regional number above to find the corresponding location id
      regional_offices = bgs_service.find_regional_offices
      return '347' if regional_offices.nil? # return default value 347 if regional office is not found

      regional_office = regional_offices.find { |ro| ro[:station_number] == regional_office_number }
      return '347' if regional_office.nil? # return default value 347 if regional office is not found

      regional_office[:lctn_id]
    end

    def veteran
      @veteran ||= BGSDependents::Veteran.new(@proc_id, @user)
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
