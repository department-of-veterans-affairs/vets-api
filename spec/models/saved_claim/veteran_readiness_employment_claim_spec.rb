# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::VeteranReadinessEmploymentClaim do
  let(:claim) { create(:veteran_readiness_employment_claim) }
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
        claimant_keys = %w[fullName ssn dob VAFileNumber pid edipi vet360ID]
        expect(claim.parsed_form['veteranInformation']).to include(
          {
            'fullName' => {
              'first' => 'Homer',
              'middle' => 'John',
              'last' => 'Simpson'
            },
            'dob' => '1809-02-12'
          }
        )

        expect(
          claim.parsed_form['veteranInformation'].keys
        ).to eq(claimant_keys)
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
          claim.add_claimant_info(user_object)
          response = claim.send_to_vre(user_object)
          expect(response['error_occurred']).to eq(false)
        end
      end

      it 'ensures appointment time preferences are downcased' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          claim.add_claimant_info(user_object)
          claim.send_to_vre(user_object)

          expect(claim.parsed_form['appointmentTimePreferences'].first).to eq('morning')
        end
      end

      it 'does not successfully send to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/failed_send_to_vre' do
          claim.add_claimant_info(user_object)
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
