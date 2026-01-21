# frozen_string_literal: true

require 'rails_helper'
require './modules/claims_api/spec/support/fake_vbms'

RSpec.describe VRE::VREVeteranReadinessEmploymentClaim do
  let(:claim) { create(:vre_veteran_readiness_employment_claim) }
  let(:user_object) { create(:evss_user, :loa3) }
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
  let(:user_struct) do
    OpenStruct.new(
      edipi: user_object.edipi,
      participant_id: user_object.participant_id,
      pid: user_object.participant_id,
      birth_date: user_object.birth_date,
      ssn: user_object.ssn,
      vet360_id: user_object.vet360_id,
      loa3?: true,
      icn: user_object.icn,
      uuid: user_object.uuid,
      first_name: user_object.first_name,
      va_profile_email: user_object.va_profile_email
    )
  end
  let(:encrypted_user) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }
  let(:user) { OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user))) }

  before do
    allow_any_instance_of(VRE::Ch31Form).to receive(:submit).and_return(true)
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
      claim.add_claimant_info(user_object)
      expect(claim.parsed_form['veteranInformation']).to include('VAFileNumber' => nil)
    end

    it 'handles blank form' do
      claim.form = nil
      expect(Rails.logger).to receive(:info)
        .with('VRE claim form is blank, skipping adding veteran info', { user_uuid: user.uuid })
      expect(claim.add_claimant_info(user)).to be_nil
    end
  end

  describe '#send_to_vre' do
    subject { claim.send_to_vre(user_object) }

    before do
      # TODO(02/2026): Remove stub when VRE::NotificationEmail uses VRE::VREVeteranReadinessEmploymentClaim
      # See: https://github.com/department-of-veterans-affairs/va-iir/issues/2011
      allow_any_instance_of(VRE::NotificationEmail).to receive(:claim_class)
        .and_return(VRE::VREVeteranReadinessEmploymentClaim)
    end

    it 'propagates errors from send_to_lighthouse!' do
      allow(claim).to receive(:process_attachments!).and_raise(StandardError, 'Attachment error')

      expect do
        claim.send_to_lighthouse!(user_object)
      end.to raise_error(StandardError, 'Attachment error')
    end

    context 'when VBMS response is VBMSDownForMaintenance' do
      before do
        allow(OpenSSL::PKCS12).to receive(:new).and_return(double.as_null_object)
        vbms_client = FakeVBMS.new
        allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
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
          # modules/vre/app/models/vre/constants.rb gets changed, you
          # may need to change this mock below and maybe even move it into different 'it'
          # blocks if you need to test different routing offices
          expect_any_instance_of(BGS::RORoutingService).to receive(:get_regional_office_by_zip_code).and_return(
            { regional_office: { number: '325' } }
          )
        end

        it 'sends confirmation email' do
          expect(claim).to receive(:send_email).with(:confirmation_vbms)

          claim.send_to_vre(user_object)
        end
      end

      # We want all submission to go through with RES
      context 'non-submission to VRE' do
        it 'stops submission if location is not in list' do
          expect_any_instance_of(VRE::Ch31Form).to receive(:submit)
          claim.add_claimant_info(user_object)

          claim.send_to_vre(user_object)
        end
      end
    end

    context 'when user has no participant ID' do
      let(:user_object) { create(:unauthorized_evss_user) }

      it 'PDF is sent to Central Mail and not VBMS' do
        expect(claim).to receive(:process_attachments!)
        expect(claim).to receive(:send_to_lighthouse!).with(user_object).once.and_call_original
        expect(claim).to receive(:send_email).with(:confirmation_lighthouse)
        expect(claim).not_to receive(:upload_to_vbms)
        expect(VRE::VeteranReadinessEmploymentMailer).to receive(:build).with(
          user_object.participant_id, 'VRE.VBAPIT@va.gov', true
        ).and_call_original
        subject
      end
    end
  end

  describe '#regional_office' do
    it 'returns an empty array' do
      expect(claim.regional_office).to eq []
    end
  end

  describe '#process_attachments!' do
    it 'processes attachments successfully' do
      allow(claim).to receive_messages(
        attachment_keys: ['some_key'],
        open_struct_form: OpenStruct.new(some_key: [OpenStruct.new(confirmationCode: '123')])
      )
      allow(PersistentAttachment).to receive(:where).and_return(double(find_each: true))
      allow_any_instance_of(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform).and_return(true)
      expect(claim.process_attachments!).to be_truthy
    end
  end

  describe '#upload_to_vbms' do
    it 'updates form with VBMS document id' do
      allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload!)
        .and_return({ vbms_document_series_ref_id: '123' })
      claim.upload_to_vbms(user: build(:user))
      expect(claim.parsed_form['documentId']).to eq('123')
    end
  end
end
