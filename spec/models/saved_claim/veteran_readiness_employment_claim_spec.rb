# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::VeteranReadinessEmploymentClaim do
  let(:claim) { create(:veteran_readiness_employment_claim_no_vet_information) }
  let(:moving_claim) { create(:veteran_readiness_employment_claim) }
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:new_address_hash) do
    {
      newAddress: {
        isForeign: false,
        isMilitary: nil,
        countryName: 'USA',
        addressLine1: '1019 Robin Cir',
        addressLine2: nil,
        addressLine3: nil,
        city: 'Arroyo Grande',
        province: 'CA',
        internationalPostalCode: '93420'
      }
    }
  end

  describe '#add_claimant_info' do
    it 'adds veteran information' do
      VCR.use_cassette 'veteran_readiness_employment/add_claimant_info' do
        claim.add_claimant_info(user_object)

        expect(claim.parsed_form['veteranInformation']).to include('VAFileNumber' => '796043735')
      end
    end

    it 'does not obtain va_file_number' do
      VCR.use_cassette 'veteran_readiness_employment/add_claimant_info' do
        people_service_object = double('people_service')
        allow(people_service_object).to receive(:find_person_by_participant_id)
        allow(BGS::PeopleService).to receive(:new) { people_service_object }

        claim.add_claimant_info(user_object)
        expect(claim.parsed_form['veteranInformation']).to include('VAFileNumber' => nil)
      end
    end
  end

  describe '#send_to_vre' do
    context 'successful submission' do
      it 'successfully sends to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          response = claim.send_to_vre(user_object)
          expect(response['error_occurred']).to eq(false)
        end
      end

      it 'does not successfully send to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_vre' do
          response = claim.send_to_vre(user_object)

          expect(response['error_occurred']).to eq(true)
        end
      end
    end
  end

  describe '#regional_office' do
    it 'returns an empty array' do
      expect(claim.regional_office).to be_empty
    end
  end
end
