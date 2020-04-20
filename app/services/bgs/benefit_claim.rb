require_relative 'value_objects/benefit_claim'

module BGS
  class BenefitClaim < Base
    def initialize(vnp_benefit_claim:, veteran:, user:)
      @vnp_benefit_claim = vnp_benefit_claim
      @veteran = veteran

      super(user)
    end

    def create
      benefit_claim = insert_benefit_claim(@vnp_benefit_claim, @veteran)

      ::ValueObjects::BenefitClaim.new(
        benefit_claim_id: benefit_claim[:benefit_claim_record][:benefit_claim_id],
        corp_benefit_claim_id: benefit_claim[:benefit_claim_record][:cp_benefit_claim_id],
        corp_claim_id: benefit_claim[:benefit_claim_record][:cp_claim_id],
        corp_location_id: benefit_claim[:benefit_claim_record][:cp_location_id],
        benefit_claim_return_label: benefit_claim[:benefit_claim_record][:benefit_claim_return_label],
        claim_receive_date: benefit_claim[:benefit_claim_record][:claim_receive_date],
        claim_station_of_jurisdiction: benefit_claim[:benefit_claim_record][:claim_station_of_jurisdiction],
        claim_type_code: benefit_claim[:benefit_claim_record][:claim_type_code],
        claim_type_name: benefit_claim[:benefit_claim_record][:claim_type_name],
        claimant_first_name: benefit_claim[:benefit_claim_record][:claimant_first_name],
        claimant_last_name: benefit_claim[:benefit_claim_record][:claimant_last_name],
        claimant_person_or_organization_indicator: benefit_claim[:benefit_claim_record][:claimant_person_or_organization_indicator],
        corp_claim_return_label: benefit_claim[:benefit_claim_record][:cp_claim_return_label],
        end_product_type_code: benefit_claim[:benefit_claim_record][:end_product_type_code],
        mailing_address_id: benefit_claim[:benefit_claim_record][:mailing_address_id],
        participant_claimant_id: benefit_claim[:benefit_claim_record][:participant_claimant_id],
        participant_vet_id: benefit_claim[:benefit_claim_record][:participant_vet_id],
        payee_type_code: benefit_claim[:benefit_claim_record][:payee_type_code],
        program_type_code: benefit_claim[:benefit_claim_record][:program_type_code],
        return_code: benefit_claim[:benefit_claim_record][:return_code],
        service_type_code: benefit_claim[:benefit_claim_record][:service_type_code],
        status_type_code: benefit_claim[:benefit_claim_record][:status_type_code],
        vet_first_name: benefit_claim[:benefit_claim_record][:vet_first_name],
        vet_last_name: benefit_claim[:benefit_claim_record][:vet_last_name]
      )
    end
  end
end
