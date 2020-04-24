require 'rails_helper'
require 'bgs/value_objects/vnp_benefit_claim'
require 'bgs/value_objects/vnp_person_address_phone'

RSpec.describe BGS::BenefitClaim do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:person_address_phone_object) do
    ValueObjects::VnpPersonAddressPhone.new(
      vnp_proc_id: proc_id,
      vnp_participant_id: participant_id,
      first_name: 'Veteran first name',
      middle_name: 'Veteran middle name',
      last_name: 'Veteran last name',
      vnp_participant_address_id: '113372',
      participant_relationship_type_name: 'Spouse',
      family_relationship_type_name: 'Spouse',
      suffix_name: 'Jr',
      birth_date: '08/08/1988',
      birth_state_code: 'FL',
      birth_city_name: 'Tampa',
      file_number: '2345678',
      ssn_number: '112347',
      phone_number: '5555555555',
      address_line_one: '123 Mainstreet',
      address_line_two: '',
      address_line_three: '',
      address_state_code: 'FL',
      address_city: 'Tampa',
      address_zip_code: '22145',
      email_address: 'foo@foo.com',
      death_date: nil,
      begin_date: nil,
      end_date: nil,
      event_date: nil,
      ever_married_indicator: 'N',
      marriage_state: '',
      marriage_city: 'Tampa',
      divorce_state: nil,
      divorce_city: nil,
      marriage_termination_type_code: nil,
      benefit_claim_type_end_product: '681',
    )
  end
  let(:vnp_benefit_claim_object) do
    ValueObjects::VnpBenefitClaim.new(
      vnp_proc_id: proc_id,
      vnp_benefit_claim_id: '424267',
      vnp_benefit_claim_type_code: '130DPNEBNADJ',
      claim_jrsdtn_lctn_id: '347',
      intake_jrsdtn_lctn_id: '347',
      claim_received_date: DateTime.current.iso8601,
      program_type_code: 'COMP',
      participant_claimant_id: user.participant_id,
      status_type_code: 'PEND',
      service_type_code: 'CP',
      participant_mail_address_id: '113372',
      vnp_participant_vet_id: '146232'
    )
  end

  describe '#create' do
    it 'returns a BenefitClaim object' do
      VCR.use_cassette('bgs/benefit_claim/create') do
        benefit_claim = BGS::BenefitClaim.new(
          vnp_benefit_claim: vnp_benefit_claim_object,
          veteran: person_address_phone_object,
          user: user
        ).create

        expect(benefit_claim).to have_attributes(
                                   benefit_claim_id: "600187115",
                                   benefit_claim_return_label: 'BNFT_CLAIM',
                                   participant_vet_id: "600048743",
                                   vet_first_name: "VETERAN FIRST NAME"
                                 )
      end
    end

    it 'calls BGS::Base#insert_benefit_claim' do
      VCR.use_cassette('bgs/benefit_claim/create') do
        expect_any_instance_of(BGS::Base).to receive(:insert_benefit_claim)
                                               .with(vnp_benefit_claim_object, person_address_phone_object)
                                               .and_call_original

        BGS::BenefitClaim.new(
          vnp_benefit_claim: vnp_benefit_claim_object,
          veteran: person_address_phone_object,
          user: user
        ).create
      end
    end
  end
end