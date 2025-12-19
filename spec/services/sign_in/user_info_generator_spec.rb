# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserInfoGenerator do
  subject(:generator) { described_class.new(user:) }

  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:idme_user_verification, idme_uuid: credential_uuid, user_account:) }

  let(:mpi_profile) do
    build(:mpi_profile, icn:, sec_id:, given_names: [first_name], family_name: last_name, edipi:, mhv_ien:, cerner_id:,
                        participant_id: corp_id, birls_id: birls, full_mvi_ids: gcids)
  end
  let(:user) do
    build(
      :user,
      user_account:,
      user_verification:,
      icn:,
      idme_uuid: credential_uuid,
      first_name:,
      last_name:
    )
  end
  let(:credential_uuid) { 'some-uuid' }
  let(:icn) { 'some-icn' }
  let(:sec_id) { 'some-sec-id' }
  let(:first_name) { 'some-first-name' }
  let(:last_name) { 'some-last-name' }
  let(:email) { 'some-email' }
  let(:client_id) { 'some-client-id' }
  let(:edipi) { 'some-edipi' }
  let(:mhv_ien) { '111222333' }
  let(:cerner_id) { 'CER12345' }
  let(:corp_id) { 'CORP67890' }
  let(:birls) { 'BIRL12345' }
  let(:gcids) do
    [
      '1000123456V123456^NI^200M^USVHA^P',
      '12345^PI^516^USVHA^PCE',
      '2^PI^553^USVHA^PCE'
    ]
  end
  let(:npi_id) { 'NPI1234567' }

  let!(:user_credential_email) { create(:user_credential_email, user_verification:, credential_email:) }
  let(:credential_email) { 'test@example.com' }

  before do
    allow(user).to receive(:mpi_profile).and_return(mpi_profile)
  end

  describe '#perform' do
    context 'when user has valid attributes' do
      it 'generates user info with expected values' do
        user_info = generator.perform

        expect(user_info.sub).to eq(credential_uuid)
        expect(user_info.ial).to eq(SignIn::Constants::Auth::IAL_TWO.to_s)
        expect(user_info.aal).to eq('http://idmanagement.gov/ns/assurance/aal/2')
        expect(user_info.csp_type).to eq(MPI::Constants::IDME_IDENTIFIER)
        expect(user_info.csp_uuid).to eq(credential_uuid)
        expect(user_info.email).to eq(credential_email)
        expect(user_info.full_name).to eq(user.full_name_normalized.values.compact.join(' '))
        expect(user_info.birth_date).to eq(user.birth_date)
        expect(user_info.ssn).to eq(user.ssn)
        expect(user_info.gender).to eq(user.gender)
        expect(user_info.address_street1).to eq(user.address[:street])
        expect(user_info.address_street2).to eq(user.address[:street2])
        expect(user_info.address_city).to eq(user.address[:city])
        expect(user_info.address_state).to eq(user.address[:state])
        expect(user_info.address_country).to eq(user.address[:country])
        expect(user_info.address_postal_code).to eq(user.address[:postal_code])
        expect(user_info.phone_number).to eq(user.home_phone)
        expect(user_info.person_types).to eq(user.person_types&.join('|') || '')
        expect(user_info.icn).to eq(user.icn)
        expect(user_info.sec_id).to eq(user.sec_id)
        expect(user_info.edipi).to eq(user.edipi)
        expect(user_info.mhv_ien).to eq(user.mhv_ien)
        expect(user_info.cerner_id).to eq(user.cerner_id)
        expect(user_info.corp_id).to eq(user.participant_id)
        expect(user_info.birls).to eq(user.birls_id)
        expect(user_info.npi_id).to eq(user.npi_id)
      end

      context 'when the gcids are valid' do
        let(:expected_gcids) do
          '1000123456V123456^NI^200M^USVHA^P|12345^PI^516^USVHA^PCE|2^PI^553^USVHA^PCE'
        end

        it 'includes them in the user info' do
          user_info = generator.perform
          expect(user_info.gcids).to eq(expected_gcids)
        end
      end

      context 'when the gcids are not authorized' do
        let(:gcids) do
          [
            '1000123456V123456^NI^200BAD^USVHA^P',
            '1000123456V123456^NI^200INVALID^USVHA^P'
          ]
        end

        it 'excludes them from the user info' do
          user_info = generator.perform
          expect(user_info.gcids).to eq('')
        end
      end
    end
  end
end
