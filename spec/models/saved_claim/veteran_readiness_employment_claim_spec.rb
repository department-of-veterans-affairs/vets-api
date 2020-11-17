# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::VeteranReadinessEmploymentClaim do
  let(:claim) { create(:veteran_readiness_employment_claimm_no_vet_information) }
  let(:moving_claim) { create(:veteran_readiness_employment_claimm) }
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
        # expect(people_service_object).to receive(:find_person_by_particpant_id).and_raise(StandardError)

        claim.add_claimant_info(user_object)
        expect(claim.parsed_form['veteranInformation']).to include('VAFileNumber' => nil)
      end
    end
  end

  describe '#send_to_vre' do
    let(:faraday_response) { double('faraday_connection') }

    context 'successful submission' do
      it 'successfully sends to VRE' do
        allow(faraday_response).to receive(:body).and_return('{"ErrorOccurred":false,"ApplicationIntake":"12345"}')
        allow_any_instance_of(Faraday::Connection).to receive(:post) { faraday_response }

        response = claim.send_to_vre
        expect(response).to eq(true)
      end

      it 'adds a new address if the user is moving within 30 days' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect(moving_claim).to receive(:new_address) { new_address_hash }

          moving_claim.send_to_vre
        end
      end

      it 'does not successfully send to VRE' do
        allow(faraday_response).to receive(:body).and_return(
          '{"ErrorOccurred":true,"ErrorMessage":"bad stuff happened"}'
        )

        allow_any_instance_of(Faraday::Connection).to receive(:post) { faraday_response }
        expect(claim).to receive(:log_exception_to_sentry)

        claim.send_to_vre
      end
    end
  end

  describe '#regional_office' do
    it 'returns an empty array' do
      expect(claim.regional_office).to be_empty
    end
  end
end
