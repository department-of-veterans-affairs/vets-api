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
        claimant_keys = %w[fullName dob pid edipi vet360ID regionalOffice VAFileNumber ssn]
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
    context 'submission to VRE' do
      before do
        expect(ClaimsApi::VBMSUploader).to receive(:new) { OpenStruct.new(upload!: true) }

        # As the PERMITTED_OFFICE_LOCATIONS constant at
        # the top of: app/models/saved_claim/veteran_readiness_employment_claim.rb gets changed, you
        # may need to change this mock below and maybe even move it into different 'it'
        # blocks if you need to test different routing offices
        expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
          { regional_office: { number: '325' } }
        )
      end

      it 'successfully sends to VRE' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          claim.add_claimant_info(user_object)
          response = claim.send_to_vre(user_object)

          # the business has asked us to put a pause on submissions
          # so this is just a temporary change but will be put back
          # expect(response['error_occurred']).to eq(false)
          expect(response).to eq(nil)
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

          # the business has asked us to put a pause on submissions
          # so this is just a temporary change but will be put back
          # expect(response['error_occurred']).to eq(true)
          expect(response).to eq(nil)
        end
      end
    end

    context 'non-submission to VRE' do
      it 'stops submission if location is not in list' do
        VCR.use_cassette 'veteran_readiness_employment/send_to_vre' do
          expect(ClaimsApi::VBMSUploader).to receive(:new) { OpenStruct.new(upload!: true) }
          expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
            { regional_office: { number: '310' } }
          )

          expect(VRE::Ch31Form).not_to receive(:new)
          claim.add_claimant_info(user_object)

          claim.send_to_vre(user_object)
        end
      end
    end
  end

  describe '#regional_office' do
    it 'returns an empty array' do
      expect(claim.regional_office).to be_empty
    end
  end

  describe '#send_to_central_mail!' do
    it 'sends the claim to central mail' do
      claim.send_to_central_mail!
    end

    it 'calls process_attachments! method' do
      expect(claim).to receive(:process_attachments!)
      claim.send_to_central_mail!
    end
  end
end
