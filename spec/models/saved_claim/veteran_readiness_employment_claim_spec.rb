# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../modules/claims_api/spec/support/fake_vbms'
require 'claims_api/vbms_uploader'

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

  before do
    allow_any_instance_of(RES::Ch31Form).to receive(:submit).and_return(true)
    Flipper.enable(:veteran_readiness_employment_to_res)
  end

  describe '#add_claimant_info' do
    it 'adds veteran information' do
      claim.add_claimant_info(user_object)
      claimant_keys = %w[fullName dob pid edipi vet360ID regionalOffice regionalOfficeName stationId VAFileNumber ssn]
      expect(claim.parsed_form['veteranInformation']).to include(
        {
          'fullName' => {
            'first' => 'Homer',
            'middle' => 'John',
            'last' => 'Simpson'
          },
          'dob' => '1986-05-06'
        }
      )

      expect(claim.parsed_form['veteranInformation']).to include(*claimant_keys)
    end

    it 'does not obtain va_file_number' do
      people_service_object = double('people_service')
      allow(people_service_object).to receive(:find_person_by_participant_id)
      allow(BGS::People::Request).to receive(:new) { people_service_object }

      claim.add_claimant_info(user_object)
      expect(claim.parsed_form['veteranInformation']).to include('VAFileNumber' => nil)
    end
  end

  describe '#send_to_vre' do
    subject { claim.send_to_vre(user_object) }

    context 'when VBMS response is VBMSDownForMaintenance' do
      before do
        allow(OpenSSL::PKCS12).to receive(:new).and_return(double.as_null_object)
        @vbms_client = FakeVBMS.new
        allow(VBMS::Client).to receive(:from_env_vars).and_return(@vbms_client)
      end

      it 'calls #send_to_lighthouse!' do
        expect(claim).to receive(:send_to_lighthouse!)
        subject
      end

      it 'does not raise an error' do
        allow(claim).to receive(:send_to_lighthouse!)
        expect { subject }.not_to raise_error
      end
    end

    context 'when VBMS upload is successful' do
      before { expect(ClaimsApi::VBMSUploader).to receive(:new) { OpenStruct.new(upload!: {}) } }

      context 'submission to VRE' do
        before do
          # As the PERMITTED_OFFICE_LOCATIONS constant at
          # the top of: app/models/saved_claim/veteran_readiness_employment_claim.rb gets changed, you
          # may need to change this mock below and maybe even move it into different 'it'
          # blocks if you need to test different routing offices
          expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
            { regional_office: { number: '325' } }
          )
        end

        it 'sends confirmation email' do
          expect(claim).to receive(:send_vbms_confirmation_email).with(user_object)

          claim.send_to_vre(user_object)
        end
      end

      # We want all submission to go through with RES
      context 'non-submission to VRE' do
        context 'flipper enabled' do
          it 'stops submission if location is not in list' do
            expect_any_instance_of(RES::Ch31Form).to receive(:submit)
            claim.add_claimant_info(user_object)

            claim.send_to_vre(user_object)
          end
        end

        context 'flipper disabled' do
          before do
            Flipper.disable(:veteran_readiness_employment_to_res)
          end

          it 'stops submission if location is not in list' do
            expect(VRE::Ch31Form).not_to receive(:new)
            claim.add_claimant_info(user_object)

            claim.send_to_vre(user_object)
          end
        end
      end
    end

    context 'when user has no PID' do
      let(:user_object) { create(:unauthorized_evss_user) }

      it 'PDF is sent to Central Mail and not VBMS' do
        expect(claim).to receive(:process_attachments!)
        expect(claim).to receive(:send_to_lighthouse!).with(user_object).once.and_call_original
        expect(claim).to receive(:send_lighthouse_confirmation_email)
        expect(claim).not_to receive(:upload_to_vbms)
        expect(VeteranReadinessEmploymentMailer).to receive(:build).with(
          user_object.participant_id, 'VRE.VBAPIT@va.gov', true
        ).and_call_original
        subject
      end
    end
  end

  describe '#regional_office' do
    it 'returns an empty array' do
      expect(claim.regional_office).to be_empty
    end
  end

  describe '#send_vbms_confirmation_email' do
    subject { claim.send_vbms_confirmation_email(user_object) }

    it 'calls the VA notify email job' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user_object.va_profile_email,
        'ch31_vbms_fake_template_id',
        {
          'date' => Time.zone.today.strftime('%B %d, %Y'),
          'first_name' => 'WESLEY'
        }
      )

      subject
    end
  end

  describe '#send_lighthouse_confirmation_email' do
    subject { claim.send_lighthouse_confirmation_email(user_object) }

    it 'calls the VA notify email job' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user_object.va_profile_email,
        'ch31_central_mail_fake_template_id',
        {
          'date' => Time.zone.today.strftime('%B %d, %Y'),
          'first_name' => 'WESLEY'
        }
      )

      subject
    end
  end
end
