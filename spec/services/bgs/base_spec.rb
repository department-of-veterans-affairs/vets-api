# frozen_string_literal: true
require 'rails_helper'
require 'bgs/value_objects/vnp_person_address_phone'
require 'bgs/value_objects/vnp_benefit_claim'
require 'bgs/value_objects/benefit_claim'

RSpec.describe BGS::Base do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:bgs_base) { BGS::Base.new(user) }
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
      ever_married_indicator: 'N',
      marriage_state: '',
      marriage_city: 'Tampa',
      divorce_state: nil,
      divorce_city: nil,
      marriage_termination_type_cd: nil,
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
  let(:benefit_claim_object) do
    ValueObjects::BenefitClaim.new(
      benefit_claim_id: '600187033',
      corp_benefit_claim_id: '600187033',
      corp_claim_id: '373417',
      corp_location_id: '322',
      benefit_claim_return_label: 'BNFT_CLAIM',
      claim_receive_date: '04/23/2020',
      claim_station_of_jurisdiction: '281',
      claim_type_code: '130DPNEBNADJ',
      claim_type_name: 'eBenefits Dependency Adjustment',
      claimant_first_name: 'VETERAN FIRST NAME',
      claimant_last_name: 'VETERAN LAST NAME',
      claimant_person_or_organization_indicator: 'P',
      corp_claim_return_label: 'CP_CLAIM',
      end_product_type_code: '683',
      mailing_address_id: '15373485',
      participant_claimant_id: '600048743',
      participant_vet_id: '600048743',
      payee_type_code: '00',
      program_type_code: 'CPL',
      return_code: 'SHAR 9999',
      service_type_code: 'CP',
      status_type_code: 'PEND',
      vet_first_name: 'VETERAN FIRST NAME',
      vet_last_name: 'VETERAN LAST NAME'
    )
  end

  describe '#create_proc' do
    it 'returns a proc record hash' do
      VCR.use_cassette('bgs/base/create_proc') do
        response = bgs_base.create_proc

        expect(response).to have_key(:vnp_proc_id)
      end
    end
  end

  describe '#create_proc_form' do
    it 'returns a proc_form' do
      VCR.use_cassette('bgs/base/create_proc_form') do
        response = bgs_base.create_proc_form(proc_id)
        binding.pry
        expect(response).to have_key(:comp_id)
      end
    end
  end

  describe '#update_proc' do
    it 'updates a proc given a proc_id' do
      VCR.use_cassette('bgs/base/update_proc') do
        response = bgs_base.update_proc(proc_id)

        expect(response).to include(vnp_proc_id: proc_id)
      end
    end
  end

  describe '#create_participant' do
    it 'creates a participant and returns a vnp_particpant_id' do
      VCR.use_cassette('bgs/base/create_participant') do
        response = bgs_base.create_participant(proc_id)
        binding.pry
        expect(response).to have_key(:vnp_ptcpnt_id)
      end
    end
  end

  describe '#create_person' do
    it 'creates a person and returns given data' do
      payload = {
        'first' => 'vet first name',
        'middle' => 'vet middle name',
        'last' => 'vet last name',
        'suffix' => 'Jr',
        'birth_date' => '07/04/1969',
        'place_of_birth_state' => 'Florida',
        'va_file_number' => '12345',
        'ssn' => '123341234',
        'death_date' => '01/01/2020',
        'ever_maried_ind' => 'Y',
        'vet_ind' => 'Y'
      }

      VCR.use_cassette('bgs/base/create_person') do
        response = bgs_base.create_person(proc_id, participant_id, payload)

        expect(response).to include(last_nm: 'vet last name')
      end
    end
  end

  describe '#create_address' do
    it 'crates an address record and returns given data' do
      payload = {
        'address_line1' => '123 mainstreet rd.',
        'city' => 'Tampa',
        'state_code' => 'FL',
        'zip_code' => '11234',
        'email_address' => 'foo@foo.com'
      }

      VCR.use_cassette('bgs/base/create_address') do
        response = bgs_base.create_address(proc_id, participant_id, payload)

        expect(response).to include(addrs_one_txt: '123 mainstreet rd.')
      end
    end
  end

  describe '#create_phone' do
    it 'creates a phone record' do
      payload = {
        'phone_number' => '5555555555'
      }

      VCR.use_cassette('bgs/base/create_phone') do
        response = bgs_base.create_phone(proc_id, participant_id, payload)

        expect(response).to have_key(:vnp_ptcpnt_phone_id)
      end
    end
  end

  describe '#create_relationship' do
    it 'creates a relationship and returns a vnp_relationship_id' do
      VCR.use_cassette('bgs/base/create_relationship') do
        response = bgs_base.create_relationship(proc_id, participant_id, person_address_phone_object)

        expect(response).to have_key(:vnp_ptcpnt_rlnshp_id)
      end
    end
  end

  describe '#create_benefit_claim' do
    it 'creates a benefit claim and returns a vnp_bnft_claim_id' do
      VCR.use_cassette('bgs/base/create_benefit_claim') do
        response = bgs_base.create_benefit_claim(proc_id, person_address_phone_object)
        binding.pry
        expect(response).to have_key(:vnp_bnft_claim_id)
      end
    end
  end

  describe '#insert_benefit_claim' do
    it 'creates a benefit claim and returns a benefit_claim_record' do
      VCR.use_cassette('bgs/base/insert_benefit_claim') do
        response = bgs_base.insert_benefit_claim(vnp_benefit_claim_object, person_address_phone_object)

        expect(response).to have_key(:benefit_claim_record)
      end
    end
  end

  describe '#vnp_bnft_claim_update' do
    it 'creates a benefit claim and returns a vnp_bnft_claim_id' do
      VCR.use_cassette('bgs/base/vnp_bnft_claim_update') do
        response = bgs_base.vnp_bnft_claim_update(benefit_claim_object, vnp_benefit_claim_object)

        expect(response).to have_key(:vnp_bnft_claim_id)
      end
    end
  end
end
