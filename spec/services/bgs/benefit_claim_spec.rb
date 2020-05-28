require 'rails_helper'

RSpec.describe BGS::BenefitClaim do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:vet_hash) do
    {
      file_number: '234567812',
      vnp_participant_id: participant_id,
      ssn_number: '112347',
      benefit_claim_type_end_product: '681',
      first_name: 'Veteran first name',
      last_name: 'Veteran last name',
      vnp_participant_address_id: '113372',
      phone_number: '5555555555',
      address_line_one: '123 Mainstreet',
      address_state_code: 'FL',
      address_country: 'USA',
      address_city: 'Tampa',
      address_zip_code: '22145',
      email_address: 'foo@foo.com',
    }
  end

  describe '#create' do
    it 'returns a BenefitClaim hash' do
      VCR.use_cassette('bgs/benefit_claim/create') do
        benefit_claim = BGS::BenefitClaim.new(
          vnp_benefit_claim: {vnp_benefit_claim_type_code: '130DPNEBNADJ'},
          veteran: vet_hash,
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
                                               .with(
                                                 {vnp_benefit_claim_type_code: '130DPNEBNADJ'},
                                                 vet_hash
                                               )
                                               .and_call_original

        BGS::BenefitClaim.new(
          vnp_benefit_claim: {vnp_benefit_claim_type_code: '130DPNEBNADJ'},
          veteran: vet_hash,
          user: user
        ).create
      end
    end
  end
end