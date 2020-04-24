require 'rails_helper'
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

  describe '#create' do
    it 'returns a VnpBenefitClaimObject' do
      VCR.use_cassette('bgs/vnp_benefit_claim/create') do
        vnp_benefit_claim = BGS::VnpBenefitClaim.new(
          proc_id: proc_id,
          veteran: person_address_phone_object,
          user: user
        ).create

        expect(vnp_benefit_claim).to have_attributes(
                                       vnp_benefit_claim_id: "424284",
                                       vnp_benefit_claim_type_code: "130DPNEBNADJ",
                                       service_type_code: "CP"
                                     )
      end
    end

    it 'calls BGS::Base#create_benefit_claim' do
      VCR.use_cassette('bgs/vnp_benefit_claim/create') do
        expect_any_instance_of(BGS::Base).to receive(:create_benefit_claim)
                                               .with(proc_id, person_address_phone_object)
                                               .and_call_original

        BGS::VnpBenefitClaim.new(
          proc_id: proc_id,
          veteran: person_address_phone_object,
          user: user
        ).create
      end
    end
  end
end